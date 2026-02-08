defmodule AmpSdk.Async do
  @moduledoc false

  alias AmpSdk.{Error, ProcessSupport, TaskSupport}

  @type shutdown_fun :: (-> :ok)

  @spec run_with_timeout((-> term()), non_neg_integer() | :infinity) ::
          {:ok, term()} | {:error, Error.t()}
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

    case start_task(task_fun) do
      {:ok, task_pid, shutdown} ->
        monitor_ref = Process.monitor(task_pid)
        result = await_result(task_pid, monitor_ref, result_ref, timeout)
        shutdown.()
        result

      {:error, reason} ->
        {:error, task_start_error(reason)}
    end
  end

  @spec start_task((-> any())) :: {:ok, pid(), shutdown_fun()} | {:error, term()}
  defp start_task(fun) do
    case TaskSupport.start_child(fun) do
      {:ok, task_pid} ->
        {:ok, task_pid, fn -> :ok end}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp await_result(task_pid, monitor_ref, result_ref, timeout) do
    receive do
      {:amp_sdk_async_result, ^result_ref, result} ->
        Process.demonitor(monitor_ref, [:flush])
        {:ok, result}

      {:DOWN, ^monitor_ref, :process, ^task_pid, reason} ->
        {:error, Error.normalize({:task_exit, reason}, kind: :task_exit)}
    after
      timeout ->
        Process.exit(task_pid, :kill)

        case ProcessSupport.await_down(monitor_ref, task_pid, 0) do
          :down ->
            :ok

          :timeout ->
            Process.demonitor(monitor_ref, [:flush])
        end

        flush_result_message(result_ref)

        {:error,
         Error.new(:task_timeout, "Task timed out after #{timeout}ms",
           cause: :timeout,
           context: %{timeout_ms: timeout}
         )}
    end
  end

  defp task_start_error(reason) do
    Error.new(:task_exit, "Task failed to start", cause: {:task_start_failed, reason})
  end

  defp flush_result_message(result_ref) do
    receive do
      {:amp_sdk_async_result, ^result_ref, _result} -> :ok
    after
      0 -> :ok
    end
  end
end
