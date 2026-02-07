defmodule AmpSdk.AsyncTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Async
  import ExUnit.CaptureLog

  test "run_with_timeout/2 does not crash caller on worker exit" do
    log =
      capture_log(fn ->
        assert {:error, {:task_exit, :boom}} = Async.run_with_timeout(fn -> exit(:boom) end, 200)
      end)

    assert log =~ "Task"

    # Reaching this assertion confirms the test process stayed alive.
    assert true
  end

  test "run_with_timeout/2 does not leak async result messages after timeout" do
    flush_async_results()

    for _ <- 1..100 do
      assert {:error, :timeout} = Async.run_with_timeout(fn -> Process.sleep(20) end, 0)
    end

    Process.sleep(10)

    assert mailbox_messages()
           |> Enum.any?(fn
             {:amp_sdk_async_result, _ref, _value} -> true
             _ -> false
           end) == false
  end

  defp mailbox_messages do
    case Process.info(self(), :messages) do
      {:messages, messages} -> messages
      _ -> []
    end
  end

  defp flush_async_results do
    receive do
      {:amp_sdk_async_result, _ref, _value} ->
        flush_async_results()
    after
      0 ->
        :ok
    end
  end
end
