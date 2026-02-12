defmodule AmpSdk.CLITest do
  use ExUnit.Case, async: false

  alias AmpSdk.CLI
  alias AmpSdk.CLI.CommandSpec
  alias AmpSdk.Error
  alias AmpSdk.TestSupport

  describe "resolve/0" do
    test "finds amp via AMP_CLI_PATH env var" do
      case System.find_executable("amp") do
        nil ->
          :skip

        amp_path ->
          TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
            assert {:ok, %CommandSpec{program: ^amp_path, argv_prefix: []}} = CLI.resolve()
          end)
      end
    end

    test "resolves .js AMP_CLI_PATH through node command" do
      temp_dir = TestSupport.tmp_dir!("amp_cli_js")
      home_dir = TestSupport.tmp_dir!("amp_cli_home")
      js_path = TestSupport.write_file!(temp_dir, "amp.js", "console.log('ok')")
      fake_node = TestSupport.write_executable!(temp_dir, "node", "#!/usr/bin/env bash\nexit 0\n")
      path = temp_dir <> ":" <> (System.get_env("PATH") || "")

      try do
        TestSupport.with_env(
          %{"AMP_CLI_PATH" => js_path, "PATH" => path, "HOME" => home_dir},
          fn ->
            assert {:ok, %CommandSpec{program: ^fake_node, argv_prefix: [^js_path]}} =
                     CLI.resolve()
          end
        )
      after
        File.rm_rf(temp_dir)
        File.rm_rf(home_dir)
      end
    end

    test "returns error for nonexistent AMP_CLI_PATH when no fallbacks are available" do
      home_dir = TestSupport.tmp_dir!("amp_cli_home")

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

    test "returns error for non-executable AMP_CLI_PATH when no fallbacks are available" do
      temp_dir = TestSupport.tmp_dir!("amp_cli_non_exec")
      home_dir = TestSupport.tmp_dir!("amp_cli_home")
      non_exec_path = TestSupport.write_file!(temp_dir, "amp", "echo hi\n")

      try do
        TestSupport.with_env(
          %{"AMP_CLI_PATH" => non_exec_path, "PATH" => "", "HOME" => home_dir},
          fn ->
            assert {:error, %Error{kind: :cli_not_found}} = CLI.resolve()
          end
        )
      after
        File.rm_rf(temp_dir)
        File.rm_rf(home_dir)
      end
    end
  end

  describe "resolve!/0" do
    test "returns command spec on success" do
      case System.find_executable("amp") do
        nil ->
          :skip

        amp_path ->
          TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path}, fn ->
            assert %CommandSpec{program: ^amp_path} = CLI.resolve!()
          end)
      end
    end

    test "raises when no CLI can be found" do
      home_dir = TestSupport.tmp_dir!("amp_cli_home")

      try do
        TestSupport.with_env(
          %{"AMP_CLI_PATH" => "/nonexistent/amp", "PATH" => "", "HOME" => home_dir},
          fn ->
            assert_raise Error, fn -> CLI.resolve!() end
          end
        )
      after
        File.rm_rf(home_dir)
      end
    end
  end
end
