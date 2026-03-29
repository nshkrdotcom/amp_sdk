defmodule AmpSdk.LiveSSHTest do
  use ExUnit.Case, async: false

  alias AmpSdk.Types.Options
  alias CliSubprocessCore.TestSupport.LiveSSH

  @moduletag :live_ssh
  @moduletag timeout: 120_000

  @live_ssh_enabled LiveSSH.enabled?()

  if not @live_ssh_enabled do
    @moduletag skip: LiveSSH.skip_reason()
  end

  setup_all do
    {:ok,
     skip: not LiveSSH.runnable?("amp"),
     skip_reason:
       "Remote SSH target #{inspect(LiveSSH.destination())} does not have a runnable `amp --version`."}
  end

  test "live SSH: AmpSdk.run/2 executes against the remote Amp CLI", %{
    skip: skip?,
    skip_reason: skip_reason
  } do
    if skip? do
      assert is_binary(skip_reason)
    else
      assert {:ok, result} =
               AmpSdk.run("Reply with exactly: AMP_LIVE_SSH_OK", %Options{
                 execution_surface: LiveSSH.execution_surface(),
                 dangerously_allow_all: true,
                 stream_timeout_ms: 120_000
               })

      assert result =~ "AMP_LIVE_SSH_OK"
    end
  end
end
