defmodule AmpSdk.CLIInvokeTest do
  use ExUnit.Case, async: false

  alias AmpSdk.{CLIInvoke, Defaults, Error, TestSupport}

  defp write_amp_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "${AMP_TEST_BLOCK_FOREVER:-0}" = "1" ]; then
      tail -f /dev/null
    fi

    if [ -n "${AMP_TEST_STDIN_FILE:-}" ]; then
      cat > "$AMP_TEST_STDIN_FILE"
    fi

    echo "${AMP_TEST_OUTPUT:-ok}"
    """

    TestSupport.write_executable!(dir, "amp_cli_invoke_stub", script)
  end

  test "invoke/2 forwards timeout/stdin and supports custom default timeout" do
    dir = TestSupport.tmp_dir!("amp_cli_invoke")
    amp_path = write_amp_stub!(dir)
    stdin_file = Path.join(dir, "stdin.txt")

    try do
      TestSupport.with_env(
        %{"AMP_CLI_PATH" => amp_path, "AMP_TEST_STDIN_FILE" => stdin_file},
        fn ->
          assert {:ok, "ok"} = CLIInvoke.invoke(["threads", "list"], stdin: "hello")
          assert File.read!(stdin_file) == "hello"
        end
      )

      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path, "AMP_TEST_BLOCK_FOREVER" => "1"}, fn ->
        assert {:error, %Error{kind: :command_timeout}} =
                 CLIInvoke.invoke(["threads", "list"], default_timeout_ms: 10)
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "shared defaults expose command timeout and CLI install messaging" do
    assert Defaults.command_timeout_ms() == 60_000
    assert Defaults.cli_install_command() == "curl -fsSL https://ampcode.com/install.sh | bash"
    assert Defaults.cli_not_found_message() =~ Defaults.cli_install_command()
  end
end
