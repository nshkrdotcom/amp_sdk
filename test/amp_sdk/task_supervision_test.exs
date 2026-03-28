defmodule AmpSdk.TaskSupervisionTest do
  use ExUnit.Case, async: false
  @moduletag capture_log: true

  alias AmpSdk.Async

  setup do
    on_exit(fn ->
      Application.ensure_all_started(:amp_sdk)
      erase_fallback_supervisor()
    end)

    erase_fallback_supervisor()
    :ok
  end

  test "Async.run_with_timeout/2 restarts the supervised task tree when app is stopped" do
    assert {:ok, _} = Application.ensure_all_started(:amp_sdk)
    assert :ok = Application.stop(:amp_sdk)
    assert Process.whereis(AmpSdk.TaskSupervisor) == nil

    assert {:ok, :ok} = Async.run_with_timeout(fn -> :ok end, 500)
    assert is_pid(Process.whereis(AmpSdk.TaskSupervisor))
  end

  defp erase_fallback_supervisor do
    :persistent_term.erase({AmpSdk.TaskSupport, :fallback_supervisor})
  catch
    _, _ ->
      :ok
  end
end
