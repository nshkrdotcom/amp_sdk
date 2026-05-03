defmodule AmpSdk.ErrorKind do
  @moduledoc false

  @known_by_code %{
    "auth-error" => :auth_error,
    "auth_error" => :auth_error,
    "cli-not-found" => :cli_not_found,
    "cli_not_found" => :cli_not_found,
    "command-execution-failed" => :command_execution_failed,
    "command-failed" => :command_failed,
    "command-timeout" => :command_timeout,
    "command_execution_failed" => :command_execution_failed,
    "command_failed" => :command_failed,
    "command_timeout" => :command_timeout,
    "config-invalid" => :config_invalid,
    "config_invalid" => :config_invalid,
    "execution-failed" => :execution_failed,
    "execution_failed" => :execution_failed,
    "invalid-configuration" => :invalid_configuration,
    "invalid-message" => :invalid_message,
    "invalid_configuration" => :invalid_configuration,
    "invalid_message" => :invalid_message,
    "no-result" => :no_result,
    "no_result" => :no_result,
    "parse-error" => :parse_error,
    "parse_error" => :parse_error,
    "stream-start-failed" => :stream_start_failed,
    "stream_start_failed" => :stream_start_failed,
    "task-exit" => :task_exit,
    "task-timeout" => :task_timeout,
    "task_exit" => :task_exit,
    "task_timeout" => :task_timeout,
    "transport-error" => :transport_error,
    "transport-exit" => :transport_exit,
    "transport_error" => :transport_error,
    "transport_exit" => :transport_exit,
    "unknown" => :unknown,
    "user-cancelled" => :execution_failed,
    "user_cancelled" => :execution_failed
  }

  @known_atoms @known_by_code
               |> Map.values()
               |> Enum.uniq()

  @spec from_external(term()) :: AmpSdk.Error.kind() | nil
  def from_external(nil), do: nil

  def from_external(kind) when is_atom(kind) do
    if kind in @known_atoms, do: kind, else: :unknown
  end

  def from_external(kind) when is_binary(kind) do
    case kind |> String.trim() |> String.downcase() do
      "" -> nil
      normalized -> Map.get(@known_by_code, normalized, :unknown)
    end
  end

  def from_external(_kind), do: nil
end
