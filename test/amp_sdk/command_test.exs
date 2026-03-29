defmodule AmpSdk.CommandTest do
  use ExUnit.Case, async: false

  alias AmpSdk.Command
  alias AmpSdk.Error
  alias AmpSdk.TestSupport
  alias CliSubprocessCore.{CommandSpec, ExecutionSurface}
  alias CliSubprocessCore.TestSupport.FakeSSH

  defp write_amp_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_PID_FILE:-}" ]; then
      echo $$ > "$AMP_TEST_PID_FILE"
    fi

    if [ -n "${AMP_TEST_ARGS_FILE:-}" ]; then
      printf '%s\n' "$@" > "$AMP_TEST_ARGS_FILE"
    fi

    if [ -n "${AMP_TEST_STDIN_FILE:-}" ]; then
      mkdir -p "$(dirname "$AMP_TEST_STDIN_FILE")"
      cat > "$AMP_TEST_STDIN_FILE"
    fi

    if [ "${AMP_TEST_BLOCK_FOREVER:-0}" = "1" ]; then
      tail -f /dev/null
    fi

    exit_code="${AMP_TEST_EXIT_CODE:-0}"
    if [ "$exit_code" != "0" ]; then
      echo "${AMP_TEST_ERROR_TEXT:-command failed}" >&2
      exit "$exit_code"
    fi

    echo "${AMP_TEST_OUTPUT:-ok}"
    """

    TestSupport.write_executable!(dir, "amp", script)
  end

  defp write_stubborn_amp_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_PID_FILE:-}" ]; then
      echo $$ > "$AMP_TEST_PID_FILE"
    fi

    trap '' TERM
    trap '' INT

    echo "tick"
    tail -f /dev/null
    """

    TestSupport.write_executable!(dir, "amp", script)
  end

  defp process_alive?(pid) when is_integer(pid) do
    case System.cmd("kill", ["-0", Integer.to_string(pid)], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp kill_process(pid) when is_integer(pid) do
    _ = System.cmd("kill", ["-9", Integer.to_string(pid)], stderr_to_stdout: true)
    :ok
  end

  defp flush_exec_messages do
    receive do
      {:stdout, _os_pid, _data} ->
        flush_exec_messages()

      {:stderr, _os_pid, _data} ->
        flush_exec_messages()

      {:DOWN, _os_pid, :process, _pid, _reason} ->
        flush_exec_messages()
    after
      0 ->
        :ok
    end
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
          "AMP_TEST_BLOCK_FOREVER" => "1"
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

  test "run/2 timeout stops spawned subprocess" do
    dir = TestSupport.tmp_dir!("amp_command_timeout_cleanup")
    amp_path = write_amp_stub!(dir)
    pid_file = Path.join(dir, "amp_pid.txt")

    try do
      TestSupport.with_env(
        %{
          "AMP_CLI_PATH" => amp_path,
          "AMP_TEST_BLOCK_FOREVER" => "1",
          "AMP_TEST_PID_FILE" => pid_file
        },
        fn ->
          assert {:error, %Error{kind: :command_timeout}} =
                   Command.run(["threads", "list"], timeout: 30)

          assert TestSupport.wait_until(fn -> File.exists?(pid_file) end, 500) == :ok

          pid =
            pid_file
            |> File.read!()
            |> String.trim()
            |> String.to_integer()

          assert TestSupport.wait_until(fn -> not process_alive?(pid) end, 1_500) == :ok
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "run/2 timeout kills stubborn subprocesses and avoids residual transport mailbox noise" do
    dir = TestSupport.tmp_dir!("amp_command_stubborn_timeout")
    amp_path = write_stubborn_amp_stub!(dir)
    pid_file = Path.join(dir, "amp_pid.txt")

    try do
      TestSupport.with_env(
        %{
          "AMP_CLI_PATH" => amp_path,
          "AMP_TEST_PID_FILE" => pid_file
        },
        fn ->
          flush_exec_messages()

          assert {:error, %Error{kind: :command_timeout}} =
                   Command.run(["threads", "list"], timeout: 20)

          assert TestSupport.wait_until(fn -> File.exists?(pid_file) end, 500) == :ok

          pid =
            pid_file
            |> File.read!()
            |> String.trim()
            |> String.to_integer()

          assert TestSupport.wait_until(fn -> not process_alive?(pid) end, 2_500) == :ok
          refute_receive {:stdout, _os_pid, _data}, 200
          refute_receive {:stderr, _os_pid, _data}, 200
        end
      )
    after
      if File.exists?(pid_file) do
        pid = pid_file |> File.read!() |> String.trim() |> String.to_integer()
        kill_process(pid)
      end

      File.rm_rf(dir)
    end
  end

  test "run/3 validates invalid stdin before attempting to run the executable" do
    command =
      %CommandSpec{
        program: System.find_executable("sh") || "/bin/sh",
        argv_prefix: ["-c", "cat > /dev/null"]
      }

    invalid_stdin = [List.duplicate("a", 20_000), {:invalid}]

    assert {:error,
            %Error{
              kind: :command_execution_failed,
              cause: {:send_failed, {:invalid_input, _}}
            }} =
             Command.run(command, [], stdin: invalid_stdin, timeout: 500)
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

  test "run/2 preserves execution_surface through the shared command lane" do
    dir = TestSupport.tmp_dir!("amp_command_fake_ssh")
    args_file = Path.join(dir, "args.txt")
    _amp_path = write_amp_stub!(dir)
    fake_ssh = FakeSSH.new!()

    try do
      execution_surface = %ExecutionSurface{
        surface_kind: :ssh_exec,
        transport_options: FakeSSH.transport_options(fake_ssh, destination: "amp.command.example")
      }

      assert {:ok, "ssh-done"} =
               Command.run(["threads", "list"],
                 env: %{
                   "AMP_TEST_ARGS_FILE" => args_file,
                   "AMP_TEST_OUTPUT" => "ssh-done",
                   "PATH" => dir <> ":" <> (System.get_env("PATH") || "")
                 },
                 execution_surface: execution_surface
               )

      assert File.read!(args_file) == "threads\nlist\n"
      assert FakeSSH.wait_until_written(fake_ssh, 1_000) == :ok

      manifest = FakeSSH.read_manifest!(fake_ssh)
      assert manifest =~ "destination=amp.command.example"
      assert manifest =~ "remote_command="
    after
      FakeSSH.cleanup(fake_ssh)
      File.rm_rf(dir)
    end
  end

  test "run/2 classifies missing remote Amp CLI as :cli_not_found" do
    fake_ssh = FakeSSH.new!()

    try do
      TestSupport.with_env(%{"PATH" => "/nonexistent_dir_only", "AMP_CLI_PATH" => nil}, fn ->
        assert {:error, %Error{} = error} =
                 Command.run(["threads", "list"],
                   execution_surface: %ExecutionSurface{
                     surface_kind: :ssh_exec,
                     transport_options:
                       FakeSSH.transport_options(fake_ssh,
                         destination: "amp.command.missing.example"
                       )
                   },
                   env: %{"PATH" => "/nonexistent_dir_only"}
                 )

        assert error.kind == :cli_not_found
        assert error.exit_code == 127
        assert error.message =~ "remote target amp.command.missing.example"
      end)
    after
      FakeSSH.cleanup(fake_ssh)
    end
  end
end
