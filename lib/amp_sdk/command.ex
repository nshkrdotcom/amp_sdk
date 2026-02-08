defmodule AmpSdk.Command do
  @moduledoc false

  alias AmpSdk.{CLI, Env, Error, Exec}
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
      [stderr_to_stdout: Keyword.get(opts, :stderr_to_stdout, true)]
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

  defp run_system_cmd(program, args, cmd_opts, stdin, timeout)
       when timeout == :infinity or (is_integer(timeout) and timeout >= 0) do
    stderr_to_stdout = Keyword.get(cmd_opts, :stderr_to_stdout, true)
    cwd = Keyword.get(cmd_opts, :cd)
    env = Env.build_cli_env(Keyword.get(cmd_opts, :env, %{}))
    timeout_deadline = timeout_deadline(timeout)

    exec_opts =
      [:stdin, :stdout, :stderr, :monitor]
      |> Exec.add_cwd(cwd)
      |> Exec.add_env(env)

    cmd = Exec.build_command(program, args)

    case :exec.run(cmd, exec_opts) do
      {:ok, pid, os_pid} ->
        with :ok <- send_stdin(pid, stdin) do
          collect_erlexec_output(
            pid,
            os_pid,
            stderr_to_stdout,
            timeout_deadline,
            [],
            []
          )
        else
          {:error, reason} ->
            stop_exec(pid)
            {:error, reason}
        end

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

  defp send_stdin(pid, nil), do: send_eof(pid)

  defp send_stdin(pid, stdin) do
    :ok = :exec.send(pid, IO.iodata_to_binary(stdin))
    send_eof(pid)
  catch
    kind, reason ->
      {:error, {:send_failed, {kind, reason}}}
  end

  defp send_eof(pid) do
    :ok = :exec.send(pid, :eof)
    :ok
  catch
    kind, reason ->
      {:error, {:send_failed, {kind, reason}}}
  end

  defp collect_erlexec_output(
         pid,
         os_pid,
         stderr_to_stdout,
         :infinity,
         stdout_chunks,
         stderr_chunks
       ) do
    receive do
      {:stdout, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)

        collect_erlexec_output(
          pid,
          os_pid,
          stderr_to_stdout,
          :infinity,
          [data | stdout_chunks],
          stderr_chunks
        )

      {:stderr, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)

        if stderr_to_stdout do
          collect_erlexec_output(
            pid,
            os_pid,
            stderr_to_stdout,
            :infinity,
            [data | stdout_chunks],
            stderr_chunks
          )
        else
          collect_erlexec_output(
            pid,
            os_pid,
            stderr_to_stdout,
            :infinity,
            stdout_chunks,
            [data | stderr_chunks]
          )
        end

      {:DOWN, ^os_pid, :process, ^pid, reason} ->
        exit_code = decode_exit_code(reason)
        output = build_output(stderr_to_stdout, stdout_chunks, stderr_chunks)
        {:ok, {output, exit_code}}
    end
  end

  defp collect_erlexec_output(
         pid,
         os_pid,
         stderr_to_stdout,
         deadline,
         stdout_chunks,
         stderr_chunks
       ) do
    case timeout_remaining(deadline) do
      :expired ->
        stop_exec(pid)
        flush_erlexec_messages(pid, os_pid)
        {:error, :timeout}

      remaining_timeout ->
        receive do
          {:stdout, ^os_pid, data} ->
            data = IO.iodata_to_binary(data)

            collect_erlexec_output(
              pid,
              os_pid,
              stderr_to_stdout,
              deadline,
              [data | stdout_chunks],
              stderr_chunks
            )

          {:stderr, ^os_pid, data} ->
            data = IO.iodata_to_binary(data)

            if stderr_to_stdout do
              collect_erlexec_output(
                pid,
                os_pid,
                stderr_to_stdout,
                deadline,
                [data | stdout_chunks],
                stderr_chunks
              )
            else
              collect_erlexec_output(
                pid,
                os_pid,
                stderr_to_stdout,
                deadline,
                stdout_chunks,
                [data | stderr_chunks]
              )
            end

          {:DOWN, ^os_pid, :process, ^pid, reason} ->
            exit_code = decode_exit_code(reason)
            output = build_output(stderr_to_stdout, stdout_chunks, stderr_chunks)
            {:ok, {output, exit_code}}
        after
          remaining_timeout ->
            stop_exec(pid)
            flush_erlexec_messages(pid, os_pid)
            {:error, :timeout}
        end
    end
  end

  defp build_output(stderr_to_stdout, stdout_chunks, stderr_chunks) do
    stdout = stdout_chunks |> Enum.reverse() |> IO.iodata_to_binary()
    stderr = stderr_chunks |> Enum.reverse() |> IO.iodata_to_binary()
    if stderr_to_stdout, do: stdout, else: stdout <> stderr
  end

  defp timeout_deadline(:infinity), do: :infinity
  defp timeout_deadline(timeout_ms), do: System.monotonic_time(:millisecond) + timeout_ms

  defp timeout_remaining(deadline_ms) do
    remaining = deadline_ms - System.monotonic_time(:millisecond)
    if remaining <= 0, do: :expired, else: remaining
  end

  defp flush_erlexec_messages(pid, os_pid) do
    receive do
      {:stdout, ^os_pid, _data} ->
        flush_erlexec_messages(pid, os_pid)

      {:stderr, ^os_pid, _data} ->
        flush_erlexec_messages(pid, os_pid)

      {:DOWN, ^os_pid, :process, ^pid, _reason} ->
        :ok
    after
      0 ->
        :ok
    end
  end

  defp stop_exec(pid) do
    :exec.stop(pid)
    :ok
  catch
    _, _ ->
      :ok
  end

  defp decode_exit_code(:normal), do: 0
  defp decode_exit_code(0), do: 0

  defp decode_exit_code({:exit_status, code}) when is_integer(code),
    do: normalize_exit_status(code)

  defp decode_exit_code({:status, code}) when is_integer(code), do: normalize_exit_status(code)
  defp decode_exit_code(code) when is_integer(code), do: normalize_exit_status(code)
  defp decode_exit_code(_reason), do: 1

  defp normalize_exit_status(code) when code > 255 and rem(code, 256) == 0, do: div(code, 256)
  defp normalize_exit_status(code), do: code

  defp maybe_trim(output, true), do: String.trim(output)
  defp maybe_trim(output, _), do: output

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp normalize_env(nil), do: %{}
  defp normalize_env(env) when is_map(env) or is_list(env), do: Env.normalize_overrides(env)

  defp format_reason({:exception, error}), do: Exception.message(error)
  defp format_reason(reason), do: inspect(reason)
end
