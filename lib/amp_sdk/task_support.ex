defmodule AmpSdk.TaskSupport do
  @moduledoc false

  @fallback_key {__MODULE__, :fallback_supervisor}
  @fallback_lock {__MODULE__, :fallback_supervisor_lock}

  @spec fallback_supervisor() :: pid()
  def fallback_supervisor do
    case current_fallback_supervisor() do
      {:ok, pid} -> pid
      :error -> ensure_fallback_supervisor()
    end
  end

  defp ensure_fallback_supervisor do
    :global.trans(@fallback_lock, fn ->
      case current_fallback_supervisor() do
        {:ok, pid} -> pid
        :error -> start_and_store_fallback_supervisor()
      end
    end)
  end

  defp start_and_store_fallback_supervisor do
    {:ok, pid} = Task.Supervisor.start_link()
    :persistent_term.put(@fallback_key, pid)
    pid
  end

  defp current_fallback_supervisor do
    case :persistent_term.get(@fallback_key, nil) do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: {:ok, pid}, else: :error

      _ ->
        :error
    end
  end
end
