defmodule AmpSdk.ErrorShapeTest do
  use ExUnit.Case, async: false

  alias AmpSdk.{Command, Error, TestSupport}
  alias AmpSdk.Types.Options

  defp write_command_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_EXIT_CODE:-}" ] && [ "$AMP_TEST_EXIT_CODE" != "0" ]; then
      echo "${AMP_TEST_ERROR_TEXT:-command failed}" >&2
      exit "$AMP_TEST_EXIT_CODE"
    fi

    echo "ok"
    """

    TestSupport.write_executable!(dir, "amp_error_command_stub", script)
  end

  defp write_stream_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    # Amp streaming sessions write prompt/input over stdin before the CLI emits JSON.
    cat > /dev/null || true

    if [ -n "${AMP_TEST_OUTPUT_JSON:-}" ]; then
      echo "$AMP_TEST_OUTPUT_JSON"
    else
      echo "ok"
    fi
    """

    TestSupport.write_executable!(dir, "amp_error_stream_stub", script)
  end

  test "Command.run returns AmpSdk.Error on process failure" do
    dir = TestSupport.tmp_dir!("amp_error_shape")
    amp_path = write_command_stub!(dir)

    try do
      TestSupport.with_env(
        %{
          "AMP_CLI_PATH" => amp_path,
          "AMP_TEST_EXIT_CODE" => "7",
          "AMP_TEST_ERROR_TEXT" => "boom"
        },
        fn ->
          assert {:error, %Error{} = error} = Command.run(["threads", "list"])
          assert error.kind == :command_failed
          assert error.exit_code == 7
          assert error.message =~ "code 7"
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "AmpSdk.run preserves structured error kinds from stream results" do
    dir = TestSupport.tmp_dir!("amp_error_shape_run")
    amp_path = write_stream_stub!(dir)

    error_json =
      Jason.encode!(%{
        type: "result",
        subtype: "error_during_execution",
        is_error: true,
        error: "something failed",
        kind: "cli_not_found",
        duration_ms: 1,
        num_turns: 1
      })

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        assert {:error, %Error{} = error} =
                 AmpSdk.run("prompt", %Options{env: %{"AMP_TEST_OUTPUT_JSON" => error_json}})

        assert error.kind == :cli_not_found
        assert error.message == "something failed"
      end)
    after
      File.rm_rf(dir)
    end
  end
end
