defmodule AmpSdk.TaskSupervisionTest do
  use ExUnit.Case, async: false
  @moduletag capture_log: true

  alias AmpSdk.Async
  alias AmpSdk.Transport.Erlexec

  setup do
    on_exit(fn ->
      Application.ensure_all_started(:amp_sdk)
      erase_fallback_supervisor()
    end)

    erase_fallback_supervisor()
    :ok
  end

  test "Async.run_with_timeout/2 restarts the supervised task tree when app is stopped" do
    assert :ok = Application.stop(:amp_sdk)
    assert Process.whereis(AmpSdk.TaskSupervisor) == nil

    assert {:ok, :ok} = Async.run_with_timeout(fn -> :ok end, 500)
    assert is_pid(Process.whereis(AmpSdk.TaskSupervisor))
  end

  test "Erlexec I/O tasks use the supervised task tree when app is stopped" do
    assert :ok = Application.stop(:amp_sdk)
    assert Process.whereis(AmpSdk.TaskSupervisor) == nil

    cat = System.find_executable("cat") || "cat"
    {:ok, transport} = Erlexec.start(command: cat, args: [])

    try do
      ref = make_ref()

      assert :ok = Erlexec.subscribe(transport, self(), ref)
      assert :ok = Erlexec.send(transport, "ping")
      assert :ok = Erlexec.end_input(transport)

      assert_receive {:amp_sdk_transport, ^ref, {:message, "ping"}}, 1_000
      assert is_pid(Process.whereis(AmpSdk.TaskSupervisor))
    after
      Erlexec.force_close(transport)
    end
  end

  defp erase_fallback_supervisor do
    :persistent_term.erase({AmpSdk.TaskSupport, :fallback_supervisor})
  catch
    _, _ ->
      :ok
  end
end
