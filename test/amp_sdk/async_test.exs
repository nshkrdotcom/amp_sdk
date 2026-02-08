defmodule AmpSdk.AsyncTest do
  use ExUnit.Case, async: true

  alias AmpSdk.{Async, Error}
  import ExUnit.CaptureLog

  test "run_with_timeout/2 does not crash caller on worker exit" do
    log =
      capture_log(fn ->
        assert {:error, %Error{} = error} = Async.run_with_timeout(fn -> exit(:boom) end, 200)
        assert error.kind == :task_exit
        assert error.message == "Task exited: :boom"
      end)

    assert log =~ "Task"

    # Reaching this assertion confirms the test process stayed alive.
    assert true
  end

  test "run_with_timeout/2 does not leak async result messages after timeout" do
    flush_async_results()

    for _ <- 1..100 do
      assert {:error, %Error{kind: :task_timeout}} =
               Async.run_with_timeout(
                 fn ->
                   receive do
                   after
                     1_000 ->
                       :ok
                   end
                 end,
                 0
               )
    end

    refute_receive {:amp_sdk_async_result, _ref, _value}, 200
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
