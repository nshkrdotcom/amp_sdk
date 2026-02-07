defmodule AmpSdk.CLIErrorTest do
  use ExUnit.Case, async: false

  alias AmpSdk.CLI
  alias AmpSdk.Error
  alias AmpSdk.TestSupport

  test "resolve/0 returns AmpSdk.Error when CLI cannot be found" do
    home_dir = TestSupport.tmp_dir!("amp_cli_error_shape")

    try do
      TestSupport.with_env(
        %{"AMP_CLI_PATH" => "/nonexistent/amp", "PATH" => "", "HOME" => home_dir},
        fn ->
          assert {:error, %Error{kind: :cli_not_found}} = CLI.resolve()
        end
      )
    after
      File.rm_rf(home_dir)
    end
  end
end
