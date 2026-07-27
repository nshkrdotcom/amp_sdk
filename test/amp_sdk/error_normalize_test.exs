defmodule AmpSdk.ErrorNormalizeTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Error
  alias CliSubprocessCore.ProviderCLI.ErrorRuntimeFailure
  alias CliSubprocessCore.ProviderFeatures.Error, as: ProviderFeatureError

  test "normalize/2 renders readable transport reasons" do
    error = Error.normalize({:transport, :not_connected}, kind: :transport_error)

    assert error.kind == :transport_error
    assert error.message == "Transport not connected"
  end

  test "normalize/2 renders readable task exit reasons" do
    error = Error.normalize({:task_exit, :boom}, kind: :task_exit)

    assert error.kind == :task_exit
    assert error.message == "Task exited: :boom"
  end

  test "from_runtime_failure/2 preserves remote CLI classification" do
    failure =
      %ErrorRuntimeFailure{
        kind: :cli_not_found,
        provider: :amp,
        message: "Amp CLI not found on remote target ssh-target.example",
        exit_code: 127,
        stderr: "env: ‘amp’: No such file or directory",
        context: %{remote?: true, destination: "ssh-target.example"}
      }

    error = Error.from_runtime_failure(failure)

    assert error.kind == :cli_not_found
    assert error.exit_code == 127
    assert error.details =~ "No such file or directory"
    assert error.context.destination == "ssh-target.example"
  end

  test "normalizes provider feature failures without losing typed context" do
    core_error = %ProviderFeatureError{
      provider: :amp,
      feature: :completion_only,
      option: :completion_only,
      support_state: :unsupported
    }

    assert %Error{
             kind: :unsupported_capability,
             context: %{
               provider: :amp,
               feature: :completion_only,
               option: :completion_only,
               support_state: :unsupported
             }
           } = Error.normalize(core_error, kind: :stream_start_failed)
  end
end
