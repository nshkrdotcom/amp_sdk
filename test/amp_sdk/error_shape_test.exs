defmodule AmpSdk.ErrorShapeTest do
  use ExUnit.Case, async: false

  alias AmpSdk.{Command, Error, TestSupport}
  alias AmpSdk.Types.Options

  defp write_amp_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_EXIT_CODE:-}" ] && [ "$AMP_TEST_EXIT_CODE" != "0" ]; then
      echo "${AMP_TEST_ERROR_TEXT:-command failed}" >&2
      exit "$AMP_TEST_EXIT_CODE"
    fi

    if [ -n "${AMP_TEST_OUTPUT_JSON:-}" ]; then
      echo "$AMP_TEST_OUTPUT_JSON"
    else
      echo "ok"
    fi
    """

    TestSupport.write_executable!(dir, "amp_error_stub", script)
  end

  test "Command.run returns AmpSdk.Error on process failure" do
    dir = TestSupport.tmp_dir!("amp_error_shape")
    amp_path = write_amp_stub!(dir)

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
          assert error.message =~ "Exit code 7"
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "AmpSdk.run returns AmpSdk.Error when stream emits error result" do
    dir = TestSupport.tmp_dir!("amp_error_shape_run")
    amp_path = write_amp_stub!(dir)

    error_json =
      Jason.encode!(%{
        type: "result",
        subtype: "error_during_execution",
        is_error: true,
        error: "something failed",
        duration_ms: 1,
        num_turns: 1
      })

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
        assert {:error, %Error{} = error} =
                 AmpSdk.run("prompt", %Options{env: %{"AMP_TEST_OUTPUT_JSON" => error_json}})

        assert error.kind == :execution_failed
        assert error.message == "something failed"
      end)
    after
      File.rm_rf(dir)
    end
  end
end
