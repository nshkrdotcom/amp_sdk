defmodule AmpSdk.CLI do
  @moduledoc """
  Resolves the Amp CLI executable through the shared core provider policy.
  """

  alias AmpSdk.Error
  alias CliSubprocessCore.{CommandSpec, ProviderCLI}

  @type resolution_result :: {:ok, CommandSpec.t()} | {:error, Error.t()}

  @spec resolve(CliSubprocessCore.ExecutionSurface.t() | map() | keyword() | nil) ::
          resolution_result()
  def resolve(execution_surface \\ nil) do
    case ProviderCLI.resolve(:amp, [], execution_surface: execution_surface) do
      {:ok, %CommandSpec{} = spec} ->
        {:ok, spec}

      {:error, %ProviderCLI.Error{} = error} ->
        {:error, provider_cli_error(error)}
    end
  end

  @spec resolve!(CliSubprocessCore.ExecutionSurface.t() | map() | keyword() | nil) ::
          CommandSpec.t()
  def resolve!(execution_surface \\ nil) do
    case resolve(execution_surface) do
      {:ok, %CommandSpec{} = spec} ->
        spec

      {:error, %Error{} = error} ->
        raise error
    end
  end

  @spec command_args(CommandSpec.t(), [String.t()]) :: [String.t()]
  defdelegate command_args(command_spec, args), to: CommandSpec

  defp provider_cli_error(%ProviderCLI.Error{} = error) do
    Error.new(:cli_not_found, error.message,
      cause: error,
      context: %{provider: error.provider},
      exit_code: 127
    )
  end
end
