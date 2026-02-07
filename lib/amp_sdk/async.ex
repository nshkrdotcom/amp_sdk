defmodule AmpSdk.Async do
  @moduledoc false

  @type shutdown_fun :: (-> :ok)

  @spec run_with_timeout((-> term()), non_neg_integer() | :infinity) ::
          {:ok, term()} | {:error, :timeout | {:task_exit, term()}}
  def run_with_timeout(fun, :infinity) when is_function(fun, 0) do
    {:ok, fun.()}
  end

  def run_with_timeout(fun, timeout)
      when is_function(fun, 0) and is_integer(timeout) and timeout >= 0 do
    result_ref = make_ref()
    caller = self()

    task_fun = fn ->
      send(caller, {:amp_sdk_async_result, result_ref, fun.()})
    end

    {task_pid, shutdown} = start_task(task_fun)
    monitor_ref = Process.monitor(task_pid)

    result = await_result(task_pid, monitor_ref, result_ref, timeout)
    shutdown.()
    result
  end

  @spec start_task((-> any())) :: {pid(), shutdown_fun()}
  defp start_task(fun) do
    {:ok, task_pid} = Task.Supervisor.start_child(AmpSdk.TaskSupervisor, fun)
    {task_pid, fn -> :ok end}
  catch
    :exit, {:noproc, _} ->
      {:ok, supervisor} = Task.Supervisor.start_link()
      {:ok, task_pid} = Task.Supervisor.start_child(supervisor, fun)

      shutdown = fn ->
        Process.exit(supervisor, :normal)
        :ok
      end

      {task_pid, shutdown}
  end

  defp await_result(task_pid, monitor_ref, result_ref, timeout) do
    receive do
      {:amp_sdk_async_result, ^result_ref, result} ->
        Process.demonitor(monitor_ref, [:flush])
        {:ok, result}

      {:DOWN, ^monitor_ref, :process, ^task_pid, reason} ->
        {:error, {:task_exit, reason}}
    after
      timeout ->
        Process.exit(task_pid, :kill)

        receive do
          {:DOWN, ^monitor_ref, :process, ^task_pid, _reason} -> :ok
        after
          0 -> Process.demonitor(monitor_ref, [:flush])
        end

        flush_result_message(result_ref)

        {:error, :timeout}
    end
  end

  defp flush_result_message(result_ref) do
    receive do
      {:amp_sdk_async_result, ^result_ref, _result} -> :ok
    after
      0 -> :ok
    end
  end
end
