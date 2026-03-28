defmodule AmpSdk.Command do
  @moduledoc """
  Synchronous Amp command helpers built on the shared core command lane.
  """

  alias AmpSdk.{CLI, Defaults, Env, Error}
  alias CliSubprocessCore.Command, as: CoreCommand
  alias CliSubprocessCore.Command.Error, as: CoreCommandError
  alias CliSubprocessCore.CommandSpec
  alias CliSubprocessCore.ExecutionSurface
  alias CliSubprocessCore.ProcessExit
  alias CliSubprocessCore.Transport.Error, as: CoreTransportError
  alias CliSubprocessCore.Transport.RunResult

  @type run_opt ::
          {:timeout, non_neg_integer() | :infinity}
          | {:stdin, iodata()}
          | {:stderr_to_stdout, boolean()}
          | {:trim_output, boolean()}
          | {:cd, String.t()}
          | {:env, map() | keyword()}
          | {:execution_surface, ExecutionSurface.t()}

  @spec run([String.t()], [run_opt()]) :: {:ok, String.t()} | {:error, Error.t()}
  def run(args, opts \\ []) when is_list(args) and is_list(opts) do
    with {:ok, command} <- CLI.resolve() do
      run(command, args, opts)
    end
  end

  @spec run(CommandSpec.t(), [String.t()], [run_opt()]) :: {:ok, String.t()} | {:error, Error.t()}
  def run(%CommandSpec{} = command, args, opts) when is_list(args) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, Defaults.command_timeout_ms())
    stderr_to_stdout = Keyword.get(opts, :stderr_to_stdout, true)
    trim_output = Keyword.get(opts, :trim_output, true)
    command_args = CLI.command_args(command, args)

    invocation =
      CoreCommand.new(
        command.program,
        command_args,
        cwd: Keyword.get(opts, :cd),
        env: Env.build_cli_env(normalize_env(Keyword.get(opts, :env)))
      )

    with {:ok, core_run_opts} <- build_core_run_opts(opts, timeout, stderr_to_stdout) do
      case CoreCommand.run(invocation, core_run_opts) do
        {:ok, %RunResult{} = result} ->
          handle_run_result(result, trim_output, stderr_to_stdout, command.program, command_args)

        {:error, %CoreCommandError{} = error} ->
          {:error, translate_command_error(error, timeout, command.program, command_args)}
      end
    end
  end

  defp handle_run_result(
         %RunResult{exit: %ProcessExit{status: :success}} = result,
         trim_output,
         stderr_to_stdout,
         _program,
         _args
       ) do
    {:ok, result |> command_output(stderr_to_stdout) |> maybe_trim(trim_output)}
  end

  defp handle_run_result(
         %RunResult{exit: %ProcessExit{} = exit} = result,
         _trim_output,
         stderr_to_stdout,
         program,
         args
       ) do
    code = exit.code || 1
    output = command_output(result, stderr_to_stdout)

    {:error,
     Error.new(:command_failed, "Exit code #{code}: #{String.trim(output)}",
       exit_code: code,
       details: output,
       context: %{program: program, args: args}
     )}
  end

  defp translate_command_error(
         %CoreCommandError{reason: {:transport, %CoreTransportError{reason: :timeout}}},
         timeout,
         program,
         args
       ) do
    Error.new(:command_timeout, "Command timed out after #{timeout}ms",
      exit_code: 124,
      context: %{program: program, args: args}
    )
  end

  defp translate_command_error(%CoreCommandError{} = error, _timeout, program, args) do
    reason = unwrap_command_error_reason(error)

    Error.new(
      :command_execution_failed,
      "Failed to execute command: #{format_reason(reason)}",
      exit_code: 127,
      cause: reason,
      context: Map.merge(%{program: program, args: args}, error.context)
    )
  end

  defp stderr_mode(true), do: :stdout
  defp stderr_mode(false), do: :separate

  defp build_core_run_opts(opts, timeout, stderr_to_stdout) do
    base_opts = [
      stdin: Keyword.get(opts, :stdin),
      timeout: timeout,
      stderr: stderr_mode(stderr_to_stdout)
    ]

    case execution_surface_opts(Keyword.get(opts, :execution_surface)) do
      {:ok, surface_opts} ->
        {:ok, Keyword.merge(base_opts, surface_opts)}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp command_output(%RunResult{} = result, true), do: result.output
  defp command_output(%RunResult{} = result, false), do: result.stdout <> result.stderr

  defp unwrap_command_error_reason(%CoreCommandError{
         reason: {:transport, %CoreTransportError{reason: reason}}
       }),
       do: reason

  defp unwrap_command_error_reason(%CoreCommandError{reason: reason}), do: reason

  defp maybe_trim(output, true), do: String.trim(output)
  defp maybe_trim(output, _), do: output

  defp normalize_env(nil), do: %{}
  defp normalize_env(env) when is_map(env) or is_list(env), do: Env.normalize_overrides(env)

  defp execution_surface_opts(nil), do: {:ok, []}

  defp execution_surface_opts(%ExecutionSurface{} = execution_surface) do
    {:ok,
     [transport_options: execution_surface.transport_options] ++
       ExecutionSurface.surface_metadata(execution_surface)}
  end

  defp execution_surface_opts(execution_surface) do
    {:error,
     Error.new(
       :invalid_configuration,
       "execution_surface must be a %CliSubprocessCore.ExecutionSurface{}",
       cause: execution_surface
     )}
  end

  defp format_reason(%_{} = exception) when is_exception(exception),
    do: Exception.message(exception)

  defp format_reason(reason), do: inspect(reason)
end
