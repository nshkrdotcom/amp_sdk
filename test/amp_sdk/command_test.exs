defmodule AmpSdk.CommandTest do
  use ExUnit.Case, async: false

  alias AmpSdk.Command
  alias AmpSdk.Error
  alias AmpSdk.TestSupport

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

    TestSupport.write_executable!(dir, "amp_stub", script)
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

    TestSupport.write_executable!(dir, "amp_stubborn_stub", script)
  end

  defp write_gated_amp_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_PID_FILE:-}" ]; then
      echo $$ > "$AMP_TEST_PID_FILE"
    fi

    if [ -n "${AMP_TEST_GATE_FIFO:-}" ]; then
      cat "$AMP_TEST_GATE_FIFO" > /dev/null
    fi

    echo "${AMP_TEST_OUTPUT:-ok}"
    """

    TestSupport.write_executable!(dir, "amp_gated_stub", script)
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

  defp create_fifo!(path) do
    case System.cmd("mkfifo", [path], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, code} -> raise "mkfifo failed with status #{code}: #{output}"
    end
  end

  defp mailbox_has_down_for_os_pid?(pid, os_pid) when is_pid(pid) and is_integer(os_pid) do
    case Process.info(pid, :messages) do
      {:messages, messages} ->
        Enum.any?(messages, fn
          {:DOWN, ^os_pid, :process, _exec_pid, _reason} -> true
          _ -> false
        end)

      _ ->
        false
    end
  end

  defp maybe_resume_process(pid) when is_pid(pid) do
    :erlang.resume_process(pid)
    :ok
  catch
    _, _ -> :ok
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

  test "run/2 timeout kills stubborn subprocesses and avoids erlexec mailbox noise" do
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
    missing_cli = %AmpSdk.CLI.CommandSpec{program: "/definitely/missing/amp", argv_prefix: []}
    invalid_stdin = [List.duplicate("a", 20_000), [300]]

    assert {:error, %Error{kind: :command_execution_failed, cause: {:send_failed, {:error, _}}}} =
             Command.run(missing_cli, ["threads", "list"], stdin: invalid_stdin, timeout: 500)
  end

  test "run/2 flushes matching stdout/stderr messages queued after :DOWN" do
    dir = TestSupport.tmp_dir!("amp_command_down_flush")
    amp_path = write_gated_amp_stub!(dir)
    pid_file = Path.join(dir, "amp_pid.txt")
    gate_fifo = Path.join(dir, "gate.fifo")

    create_fifo!(gate_fifo)

    try do
      TestSupport.with_env(
        %{
          "AMP_CLI_PATH" => amp_path,
          "AMP_TEST_PID_FILE" => pid_file,
          "AMP_TEST_GATE_FIFO" => gate_fifo
        },
        fn ->
          parent = self()

          worker =
            spawn(fn ->
              send(parent, {:command_worker_started, self()})

              result = Command.run(["threads", "list"], timeout: 5_000)

              messages =
                case Process.info(self(), :messages) do
                  {:messages, current} -> current
                  _ -> []
                end

              send(parent, {:command_worker_finished, result, messages})
            end)

          try do
            assert_receive {:command_worker_started, ^worker}, 500
            assert TestSupport.wait_until(fn -> File.exists?(pid_file) end, 1_000) == :ok
            os_pid = pid_file |> File.read!() |> String.trim() |> String.to_integer()

            _ = :erlang.suspend_process(worker)

            try do
              File.write!(gate_fifo, "go")
              assert TestSupport.wait_until(fn -> not process_alive?(os_pid) end, 1_000) == :ok

              assert TestSupport.wait_until(
                       fn -> mailbox_has_down_for_os_pid?(worker, os_pid) end,
                       1_000
                     ) ==
                       :ok

              send(worker, {:stdout, os_pid, "injected-stdout"})
              send(worker, {:stderr, os_pid, "injected-stderr"})
            after
              :ok = maybe_resume_process(worker)
            end

            assert_receive {:command_worker_finished, {:ok, "ok"}, leftover_messages}, 2_000

            refute Enum.any?(leftover_messages, fn
                     {:stdout, ^os_pid, "injected-stdout"} -> true
                     {:stderr, ^os_pid, "injected-stderr"} -> true
                     _ -> false
                   end)
          after
            if Process.alive?(worker) do
              Process.exit(worker, :kill)
            end
          end
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
