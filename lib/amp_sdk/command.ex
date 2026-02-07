defmodule AmpSdk.Command do
  @moduledoc false

  alias AmpSdk.{Async, CLI, Env, Error, Exec}
  alias AmpSdk.CLI.CommandSpec

  @default_timeout_ms 60_000

  @type run_opt ::
          {:timeout, non_neg_integer() | :infinity}
          | {:stdin, iodata()}
          | {:stderr_to_stdout, boolean()}
          | {:trim_output, boolean()}
          | {:cd, String.t()}
          | {:env, map() | keyword()}

  @spec run([String.t()], [run_opt()]) :: {:ok, String.t()} | {:error, Error.t()}
  def run(args, opts \\ []) when is_list(args) and is_list(opts) do
    with {:ok, command} <- CLI.resolve() do
      run(command, args, opts)
    end
  end

  @spec run(CommandSpec.t(), [String.t()], [run_opt()]) :: {:ok, String.t()} | {:error, Error.t()}
  def run(%CommandSpec{} = command, args, opts) when is_list(args) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    trim_output = Keyword.get(opts, :trim_output, true)
    stdin = Keyword.get(opts, :stdin)

    cmd_opts =
      []
      |> maybe_put(:stderr_to_stdout, Keyword.get(opts, :stderr_to_stdout, true))
      |> maybe_put(:cd, Keyword.get(opts, :cd))
      |> maybe_put(:env, normalize_env(Keyword.get(opts, :env)))

    command_args = CLI.command_args(command, args)

    case run_system_cmd(command.program, command_args, cmd_opts, stdin, timeout) do
      {:ok, {output, 0}} ->
        {:ok, maybe_trim(output, trim_output)}

      {:ok, {output, code}} ->
        {:error,
         Error.new(:command_failed, "Exit code #{code}: #{String.trim(output)}",
           exit_code: code,
           details: output,
           context: %{program: command.program, args: command_args}
         )}

      {:error, :timeout} ->
        {:error,
         Error.new(:command_timeout, "Command timed out after #{timeout}ms",
           exit_code: 124,
           context: %{program: command.program, args: command_args}
         )}

      {:error, {:task_exit, reason}} ->
        {:error,
         Error.new(:task_exit, "Command worker exited: #{inspect(reason)}",
           cause: reason,
           context: %{program: command.program, args: command_args}
         )}

      {:error, reason} ->
        {:error,
         Error.new(
           :command_execution_failed,
           "Failed to execute command: #{format_reason(reason)}",
           exit_code: 127,
           cause: reason,
           context: %{program: command.program, args: command_args}
         )}
    end
  end

  defp run_system_cmd(program, args, cmd_opts, stdin, :infinity) do
    run_system_cmd_once(program, args, cmd_opts, stdin)
  end

  defp run_system_cmd(program, args, cmd_opts, stdin, timeout)
       when is_integer(timeout) and timeout >= 0 do
    case Async.run_with_timeout(
           fn -> run_system_cmd_once(program, args, cmd_opts, stdin) end,
           timeout
         ) do
      {:ok, result} -> result
      {:error, :timeout} -> {:error, :timeout}
      {:error, {:task_exit, reason}} -> {:error, {:task_exit, reason}}
    end
  end

  defp run_system_cmd_once(program, args, cmd_opts, nil) do
    safe_system_cmd(program, args, cmd_opts)
  end

  defp run_system_cmd_once(program, args, cmd_opts, stdin) do
    safe_erlexec_cmd(program, args, cmd_opts, stdin)
  end

  defp safe_system_cmd(program, args, cmd_opts) do
    {:ok, System.cmd(program, args, cmd_opts)}
  rescue
    error ->
      {:error, {:exception, error}}
  catch
    kind, reason ->
      {:error, {kind, reason}}
  end

  defp safe_erlexec_cmd(program, args, cmd_opts, stdin) do
    stderr_to_stdout = Keyword.get(cmd_opts, :stderr_to_stdout, true)
    cwd = Keyword.get(cmd_opts, :cd)
    env = Env.merge_overrides(Keyword.get(cmd_opts, :env, %{}))

    exec_opts =
      [:stdin, :stdout, :stderr, :monitor]
      |> Exec.add_cwd(cwd)
      |> Exec.add_env(env)

    cmd = Exec.build_command(program, args)

    case :exec.run(cmd, exec_opts) do
      {:ok, pid, os_pid} ->
        :ok = :exec.send(pid, IO.iodata_to_binary(stdin))
        :ok = :exec.send(pid, :eof)
        collect_erlexec_output(pid, os_pid, stderr_to_stdout, "", "")

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error ->
      {:error, {:exception, error}}
  catch
    kind, reason ->
      {:error, {kind, reason}}
  end

  defp collect_erlexec_output(pid, os_pid, stderr_to_stdout, stdout, stderr) do
    receive do
      {:stdout, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)
        collect_erlexec_output(pid, os_pid, stderr_to_stdout, stdout <> data, stderr)

      {:stderr, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)

        if stderr_to_stdout do
          collect_erlexec_output(pid, os_pid, stderr_to_stdout, stdout <> data, stderr)
        else
          collect_erlexec_output(pid, os_pid, stderr_to_stdout, stdout, stderr <> data)
        end

      {:DOWN, ^os_pid, :process, ^pid, reason} ->
        exit_code = decode_exit_code(reason)
        output = if stderr_to_stdout, do: stdout, else: stdout <> stderr
        {:ok, {output, exit_code}}
    end
  end

  defp decode_exit_code(:normal), do: 0
  defp decode_exit_code(0), do: 0
  defp decode_exit_code({:exit_status, code}) when is_integer(code), do: code
  defp decode_exit_code({:status, code}) when is_integer(code), do: code
  defp decode_exit_code(code) when is_integer(code), do: code
  defp decode_exit_code(_reason), do: 1

  defp maybe_trim(output, true), do: String.trim(output)
  defp maybe_trim(output, _), do: output

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, false), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp normalize_env(nil), do: %{}
  defp normalize_env(env) when is_map(env) or is_list(env), do: Env.normalize_overrides(env)

  defp format_reason({:exception, error}), do: Exception.message(error)
  defp format_reason(reason), do: inspect(reason)
end
