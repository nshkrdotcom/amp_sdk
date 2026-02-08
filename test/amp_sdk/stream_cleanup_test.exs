defmodule AmpSdk.StreamCleanupTest do
  use ExUnit.Case, async: false

  alias AmpSdk.TestSupport
  alias AmpSdk.Types.{Options, Permission}

  defp write_blocking_stream_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_PID_FILE:-}" ]; then
      echo $$ > "$AMP_TEST_PID_FILE"
    fi

    # Keep process alive until stdin is closed by transport cleanup.
    cat > /dev/null || true
    """

    TestSupport.write_executable!(dir, "amp_stream_cleanup_stub", script)
  end

  defp write_stubborn_stream_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_PID_FILE:-}" ]; then
      echo $$ > "$AMP_TEST_PID_FILE"
    fi

    trap '' TERM
    trap '' INT

    tail -f /dev/null
    """

    TestSupport.write_executable!(dir, "amp_stream_stubborn_stub", script)
  end

  defp write_trailing_events_stream_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    cat > /dev/null || true

    echo '{"type":"result","subtype":"success","session_id":"T-cleanup","is_error":false,"result":"ok","duration_ms":1,"num_turns":1}'
    echo '{"type":"assistant","session_id":"T-cleanup","message":{"role":"assistant","content":[{"type":"text","text":"late"}]}}'
    echo "late stderr" >&2
    """

    TestSupport.write_executable!(dir, "amp_stream_trailing_stub", script)
  end

  defp process_alive?(pid) when is_integer(pid) do
    case System.cmd("kill", ["-0", Integer.to_string(pid)], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp flush_transport_messages do
    receive do
      {:amp_sdk_transport, _ref, _event} ->
        flush_transport_messages()
    after
      0 ->
        :ok
    end
  end

  test "startup failure cleans transport process and temp settings directory" do
    dir = TestSupport.tmp_dir!("amp_stream_cleanup")
    pid_file = Path.join(dir, "amp_pid.txt")
    amp_path = write_blocking_stream_stub!(dir)

    existing_temp_dirs =
      System.tmp_dir!()
      |> Path.join("amp-*")
      |> Path.wildcard()
      |> MapSet.new()

    opts = %Options{
      permissions: [Permission.new!("Bash", "ask")],
      env: %{
        "AMP_TEST_PID_FILE" => pid_file
      },
      stream_timeout_ms: 200
    }

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        result = AmpSdk.execute([], opts) |> Enum.to_list()
        assert [%AmpSdk.Types.ErrorResultMessage{} = msg] = result
        assert msg.error =~ "empty_input_messages"

        if File.exists?(pid_file) do
          pid = pid_file |> File.read!() |> String.trim() |> String.to_integer()
          assert TestSupport.wait_until(fn -> not process_alive?(pid) end, 1_000) == :ok
        end

        new_temp_dirs =
          System.tmp_dir!()
          |> Path.join("amp-*")
          |> Path.wildcard()
          |> MapSet.new()

        leaked = MapSet.difference(new_temp_dirs, existing_temp_dirs)
        assert MapSet.size(leaked) == 0
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "cleanup drains trailing transport events after final result" do
    dir = TestSupport.tmp_dir!("amp_stream_mailbox_cleanup")
    amp_path = write_trailing_events_stream_stub!(dir)

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        flush_transport_messages()

        messages = AmpSdk.execute("hello", %Options{}) |> Enum.to_list()
        assert [%AmpSdk.Types.ResultMessage{result: "ok"}] = messages

        refute_receive {:amp_sdk_transport, _ref, _event}, 200
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "timeout cleanup force-stops stubborn subprocesses" do
    dir = TestSupport.tmp_dir!("amp_stream_stubborn_cleanup")
    pid_file = Path.join(dir, "amp_pid.txt")
    amp_path = write_stubborn_stream_stub!(dir)

    opts = %Options{
      stream_timeout_ms: 50,
      env: %{"AMP_TEST_PID_FILE" => pid_file}
    }

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        flush_transport_messages()

        messages = AmpSdk.execute("hello", opts) |> Enum.to_list()
        assert [%AmpSdk.Types.ErrorResultMessage{} = msg] = messages
        assert msg.error =~ "Timed out"

        assert TestSupport.wait_until(fn -> File.exists?(pid_file) end, 1_000) == :ok
        pid = pid_file |> File.read!() |> String.trim() |> String.to_integer()
        assert TestSupport.wait_until(fn -> not process_alive?(pid) end, 4_000) == :ok

        refute_receive {:amp_sdk_transport, _ref, _event}, 200
      end)
    after
      File.rm_rf(dir)
    end
  end
end
