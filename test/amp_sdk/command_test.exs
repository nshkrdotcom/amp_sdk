defmodule AmpSdk.CommandTest do
  use ExUnit.Case, async: false

  alias AmpSdk.Command
  alias AmpSdk.Error
  alias AmpSdk.TestSupport

  defp write_amp_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_ARGS_FILE:-}" ]; then
      printf '%s\n' "$@" > "$AMP_TEST_ARGS_FILE"
    fi

    if [ -n "${AMP_TEST_STDIN_FILE:-}" ]; then
      cat > "$AMP_TEST_STDIN_FILE"
    fi

    sleep_sec="${AMP_TEST_SLEEP_SEC:-0}"
    if [ "$sleep_sec" != "0" ]; then
      sleep "$sleep_sec"
    fi

    exit_code="${AMP_TEST_EXIT_CODE:-0}"
    if [ "$exit_code" != "0" ]; then
      echo "${AMP_TEST_ERROR_TEXT:-command failed}" >&2
      exit "$exit_code"
    fi

    echo "${AMP_TEST_OUTPUT:-ok}"
    """

    TestSupport.write_executable!(dir, "amp_stub", script)
  end

  test "run/2 executes command with resolved CLI" do
    dir = TestSupport.tmp_dir!("amp_command")
    args_file = Path.join(dir, "args.txt")
    amp_path = write_amp_stub!(dir)

    try do
      TestSupport.with_env(
        %{
          "AMP_CLI_PATH" => amp_path,
          "AMP_TEST_ARGS_FILE" => args_file,
          "AMP_TEST_OUTPUT" => "done"
        },
        fn ->
          assert {:ok, "done"} = Command.run(["threads", "list"])
          assert File.read!(args_file) == "threads\nlist\n"
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "run/2 maps non-zero exits to AmpSdk.Error" do
    dir = TestSupport.tmp_dir!("amp_command")
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
          assert error.details =~ "boom"
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "run/2 enforces timeout" do
    dir = TestSupport.tmp_dir!("amp_command")
    amp_path = write_amp_stub!(dir)

    try do
      TestSupport.with_env(
        %{
          "AMP_CLI_PATH" => amp_path,
          "AMP_TEST_SLEEP_SEC" => "0.2"
        },
        fn ->
          assert {:error, %Error{} = error} = Command.run(["threads", "list"], timeout: 10)
          assert error.kind == :command_timeout
          assert error.exit_code == 124
          assert error.message =~ "timed out"
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "run/2 works with node-backed CLI paths" do
    dir = TestSupport.tmp_dir!("amp_command_node")
    args_file = Path.join(dir, "node_args.txt")
    js_path = TestSupport.write_file!(dir, "amp.js", "console.log('ok')")

    TestSupport.write_executable!(
      dir,
      "node",
      "#!/usr/bin/env bash\nprintf '%s\\n' \"$@\" > \"$AMP_TEST_ARGS_FILE\"\necho node-ok\n"
    )

    path = dir <> ":" <> (System.get_env("PATH") || "")

    try do
      TestSupport.with_env(
        %{
          "AMP_CLI_PATH" => js_path,
          "PATH" => path,
          "AMP_TEST_ARGS_FILE" => args_file
        },
        fn ->
          assert {:ok, "node-ok"} = Command.run(["threads", "list"])
          assert File.read!(args_file) == "#{js_path}\nthreads\nlist\n"
        end
      )
    after
      File.rm_rf(dir)
    end
  end
end
