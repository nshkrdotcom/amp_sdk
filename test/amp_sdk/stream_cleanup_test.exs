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

    sleep_sec="${AMP_TEST_SLEEP_SEC:-2}"
    sleep "$sleep_sec"
    """

    TestSupport.write_executable!(dir, "amp_stream_cleanup_stub", script)
  end

  defp process_alive?(pid) when is_integer(pid) do
    case System.cmd("kill", ["-0", Integer.to_string(pid)]) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp wait_until(fun, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_until(fun, deadline)
  end

  defp do_wait_until(fun, deadline) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        :timeout
      else
        Process.sleep(20)
        do_wait_until(fun, deadline)
      end
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
        "AMP_TEST_PID_FILE" => pid_file,
        "AMP_TEST_SLEEP_SEC" => "2"
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
          assert wait_until(fn -> not process_alive?(pid) end, 1_000) == :ok
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
end
