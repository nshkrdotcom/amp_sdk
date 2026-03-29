defmodule AmpSdk.LiveSSHTest do
  use ExUnit.Case, async: false

  alias AmpSdk.Error
  alias AmpSdk.Types.Options
  alias CliSubprocessCore.TestSupport.LiveSSH

  @moduletag :live_ssh
  @moduletag timeout: 120_000

  @live_ssh_enabled LiveSSH.enabled?()

  if not @live_ssh_enabled do
    @moduletag skip: LiveSSH.skip_reason()
  end

  test "live SSH: AmpSdk.run/2 returns a remote success or a structured runtime failure" do
    case AmpSdk.run("Reply with exactly: AMP_LIVE_SSH_OK", %Options{
           execution_surface: LiveSSH.execution_surface(),
           dangerously_allow_all: true,
           stream_timeout_ms: 120_000
         }) do
      {:ok, result} ->
        assert result =~ "AMP_LIVE_SSH_OK"

      {:error, %Error{kind: :cli_not_found} = error} ->
        assert error.message =~ "Amp CLI not found"
        assert error.message =~ "remote"
        assert error.details =~ "No such file or directory"

      {:error, %Error{kind: :auth_error} = error} ->
        assert error.message =~ "authentication"
    end
  end
end
