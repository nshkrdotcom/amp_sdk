defmodule AmpSdk.Async do
  @moduledoc false

  alias AmpSdk.{Error, TaskSupport}

  @spec run_with_timeout((-> term()), non_neg_integer() | :infinity) ::
          {:ok, term()} | {:error, Error.t()}
  def run_with_timeout(fun, :infinity) when is_function(fun, 0) do
    {:ok, fun.()}
  end

  def run_with_timeout(fun, timeout)
      when is_function(fun, 0) and is_integer(timeout) and timeout >= 0 do
    case TaskSupport.async_nolink(fun) do
      {:ok, task} ->
        await_result(task, timeout)

      {:error, reason} ->
        {:error, task_start_error(reason)}
    end
  end

  defp await_result(task, timeout) do
    case TaskSupport.await(task, timeout, :brutal_kill) do
      {:ok, result} ->
        {:ok, result}

      {:exit, reason} ->
        {:error, Error.normalize({:task_exit, reason}, kind: :task_exit)}

      {:error, :timeout} ->
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
end
