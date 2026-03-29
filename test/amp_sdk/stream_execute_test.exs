defmodule AmpSdk.StreamExecuteTest do
  use ExUnit.Case, async: false

  alias AmpSdk.TestSupport
  alias AmpSdk.Types.{ErrorResultMessage, Options, ResultMessage, SystemMessage}
  alias CliSubprocessCore.ExecutionSurface
  alias CliSubprocessCore.TestSupport.FakeSSH

  defp write_stream_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_STDIN_FILE:-}" ]; then
      cat > "$AMP_TEST_STDIN_FILE"
    else
      cat > /dev/null || true
    fi

    if [ "${AMP_TEST_BLOCK_FOREVER:-0}" = "1" ]; then
      tail -f /dev/null
    fi

    if [ -n "${AMP_TEST_OUTPUT_JSON:-}" ]; then
      echo "$AMP_TEST_OUTPUT_JSON"
    fi
    """

    TestSupport.write_executable!(dir, "amp", script)
  end

  defp write_prompt_arg_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_ARGS_FILE:-}" ]; then
      printf '%s\n' "$@" > "$AMP_TEST_ARGS_FILE"
    fi

    if [ -n "${AMP_TEST_STDIN_FILE:-}" ]; then
      cat > "$AMP_TEST_STDIN_FILE"
    else
      cat > /dev/null || true
    fi

    echo '{"type":"result","subtype":"success","is_error":false,"result":"ok","duration_ms":1,"num_turns":1}'
    """

    TestSupport.write_executable!(dir, "amp", script)
  end

  defp write_stderr_exit_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    cat > /dev/null || true
    echo "amp stream failed hard" >&2
    exit 7
    """

    TestSupport.write_executable!(dir, "amp", script)
  end

  defp write_large_stderr_exit_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    cat > /dev/null || true
    for i in $(seq 1 200); do
      printf 'stderr-line-%03d\\n' "$i" >&2
    done
    exit 9
    """

    TestSupport.write_executable!(dir, "amp", script)
  end

  test "execute/2 accepts user input message lists" do
    dir = TestSupport.tmp_dir!("amp_stream_execute")
    stdin_file = Path.join(dir, "stdin.jsonl")
    amp_path = write_stream_stub!(dir)

    output_json =
      Jason.encode!(%{
        type: "result",
        subtype: "success",
        is_error: false,
        result: "ok",
        duration_ms: 1,
        num_turns: 1
      })

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        messages =
          [AmpSdk.create_user_message("hello from test")]
          |> AmpSdk.execute(%Options{
            stream_timeout_ms: 5_000,
            env: %{
              "AMP_TEST_STDIN_FILE" => stdin_file,
              "AMP_TEST_OUTPUT_JSON" => output_json
            }
          })
          |> Enum.to_list()

        assert [%ResultMessage{result: "ok"}] = messages

        stdin = File.read!(stdin_file)
        assert stdin =~ "\"type\":\"user\""
        assert stdin =~ "hello from test"
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "execute/2 embeds prompt input in argv and keeps stdin empty" do
    dir = TestSupport.tmp_dir!("amp_stream_prompt_argv")
    args_file = Path.join(dir, "args.txt")
    stdin_file = Path.join(dir, "stdin.txt")
    amp_path = write_prompt_arg_stub!(dir)

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        messages =
          AmpSdk.execute("hello from prompt", %Options{
            env: %{
              "AMP_TEST_ARGS_FILE" => args_file,
              "AMP_TEST_STDIN_FILE" => stdin_file
            }
          })
          |> Enum.to_list()

        assert [%ResultMessage{result: "ok"}] = messages

        args =
          args_file
          |> File.read!()
          |> String.split("\n", trim: true)

        execute_idx = Enum.find_index(args, &(&1 == "--execute"))
        assert is_integer(execute_idx)
        assert Enum.at(args, execute_idx + 1) == "hello from prompt"
        assert "--stream-json" in args
        assert File.read!(stdin_file) == ""
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "execute/2 emits timeout error when no output arrives" do
    dir = TestSupport.tmp_dir!("amp_stream_timeout")
    amp_path = write_stream_stub!(dir)

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        messages =
          AmpSdk.execute("wait", %Options{
            stream_timeout_ms: 10,
            env: %{"AMP_TEST_BLOCK_FOREVER" => "1"}
          })
          |> Enum.to_list()

        assert [%ErrorResultMessage{} = error] = messages
        assert error.error =~ "Timed out"
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "execute/2 preserves execution_surface through the shared stream lane" do
    dir = TestSupport.tmp_dir!("amp_stream_fake_ssh")
    _amp_path = write_stream_stub!(dir)
    fake_ssh = FakeSSH.new!()

    output_json =
      Jason.encode!(%{
        type: "result",
        subtype: "success",
        session_id: "T-stream-ssh",
        is_error: false,
        result: "ssh-ok",
        duration_ms: 1,
        num_turns: 1
      })

    try do
      execution_surface = %ExecutionSurface{
        surface_kind: :static_ssh,
        transport_options: FakeSSH.transport_options(fake_ssh, destination: "amp.stream.example"),
        target_id: "amp-stream-target"
      }

      messages =
        AmpSdk.execute("hello over ssh", %Options{
          execution_surface: execution_surface,
          env: %{
            "AMP_TEST_OUTPUT_JSON" => output_json,
            "PATH" => dir <> ":" <> (System.get_env("PATH") || "")
          }
        })
        |> Enum.to_list()

      assert [
               %SystemMessage{session_id: "T-stream-ssh"},
               %ResultMessage{session_id: "T-stream-ssh", result: "ssh-ok"}
             ] = messages

      assert FakeSSH.wait_until_written(fake_ssh, 1_000) == :ok

      manifest = FakeSSH.read_manifest!(fake_ssh)
      assert manifest =~ "destination=amp.stream.example"
      assert manifest =~ "remote_command="
    after
      FakeSSH.cleanup(fake_ssh)
      File.rm_rf(dir)
    end
  end

  test "execute/2 includes structured transport exit details" do
    dir = TestSupport.tmp_dir!("amp_stream_stderr_exit")
    amp_path = write_stderr_exit_stub!(dir)

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        messages = AmpSdk.execute("boom", %Options{}) |> Enum.to_list()

        assert [%ErrorResultMessage{} = error] = messages
        assert error.kind == :transport_exit
        assert error.exit_code == 7
        assert error.stderr =~ "amp stream failed hard"
        assert is_map(error.details)
        assert error.details["exit_code"] == 7
        assert error.details["stderr"] =~ "amp stream failed hard"
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "execute/2 surfaces missing remote Amp CLIs as :cli_not_found" do
    fake_ssh = FakeSSH.new!()

    try do
      messages =
        AmpSdk.execute("boom", %Options{
          execution_surface: %ExecutionSurface{
            surface_kind: :static_ssh,
            transport_options:
              FakeSSH.transport_options(fake_ssh, destination: "amp.stream.missing.example")
          },
          env: %{"PATH" => "/nonexistent_dir_only"}
        })
        |> Enum.to_list()

      assert [%ErrorResultMessage{} = error] = messages
      assert error.kind == :cli_not_found
      assert error.exit_code == 127
      assert error.error =~ "remote target amp.stream.missing.example"
    after
      FakeSSH.cleanup(fake_ssh)
    end
  end

  test "execute/2 caps stderr tail and flags truncation metadata" do
    dir = TestSupport.tmp_dir!("amp_stream_large_stderr_exit")
    amp_path = write_large_stderr_exit_stub!(dir)

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        messages =
          AmpSdk.execute("boom", %Options{max_stderr_buffer_bytes: 96})
          |> Enum.to_list()

        assert [%ErrorResultMessage{} = error] = messages
        assert error.kind == :transport_exit
        assert error.exit_code == 9
        assert error.stderr_truncated? == true
        assert byte_size(error.stderr || "") <= 96
        assert error.stderr =~ "stderr-line-200"
        refute error.stderr =~ "stderr-line-001"
        assert error.details["stderr_truncated?"] == true
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "execute/2 does not consume unrelated mailbox messages" do
    dir = TestSupport.tmp_dir!("amp_stream_mailbox")
    amp_path = write_stream_stub!(dir)
    marker = make_ref()

    output_json =
      Jason.encode!(%{
        type: "result",
        subtype: "success",
        is_error: false,
        result: "mailbox-ok",
        duration_ms: 1,
        num_turns: 1
      })

    send(self(), {:unrelated_message, marker})

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        messages =
          AmpSdk.execute("mailbox safety", %Options{
            env: %{"AMP_TEST_OUTPUT_JSON" => output_json}
          })
          |> Enum.to_list()

        assert [%ResultMessage{result: "mailbox-ok"}] = messages
        assert_received {:unrelated_message, ^marker}
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "execute/2 emits a system message before a terminal result when the session id first arrives there" do
    dir = TestSupport.tmp_dir!("amp_stream_result_session_id")
    amp_path = write_stream_stub!(dir)

    output_json =
      Jason.encode!(%{
        type: "result",
        subtype: "success",
        session_id: "T-stream-session",
        is_error: false,
        result: "ok",
        duration_ms: 1,
        num_turns: 1
      })

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        messages =
          AmpSdk.execute("session id", %Options{
            env: %{"AMP_TEST_OUTPUT_JSON" => output_json}
          })
          |> Enum.to_list()

        assert [
                 %SystemMessage{session_id: "T-stream-session"},
                 %ResultMessage{session_id: "T-stream-session", result: "ok"}
               ] = messages
      end)
    after
      File.rm_rf(dir)
    end
  end
end
