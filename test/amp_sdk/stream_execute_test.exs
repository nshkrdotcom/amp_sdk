defmodule AmpSdk.StreamExecuteTest do
  use ExUnit.Case, async: false

  alias AmpSdk.TestSupport
  alias AmpSdk.Types.{ErrorResultMessage, Options, ResultMessage}

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

    TestSupport.write_executable!(dir, "amp_stream_stub", script)
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
end
