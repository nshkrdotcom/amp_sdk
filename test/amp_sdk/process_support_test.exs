defmodule AmpSdk.ProcessSupportTest do
  use ExUnit.Case, async: true

  alias AmpSdk.ProcessSupport

  test "await_down/3 returns :down when monitored process exits" do
    pid =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    ref = Process.monitor(pid)
    send(pid, :stop)

    assert :down = ProcessSupport.await_down(ref, pid, 200)
  end

  test "await_down/3 returns :timeout when process does not exit in time" do
    pid =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    ref = Process.monitor(pid)

    try do
      assert :timeout = ProcessSupport.await_down(ref, pid, 0)
    after
      send(pid, :stop)
      _ = ProcessSupport.await_down(ref, pid, 200)
    end
  end
end
