defmodule AmpSdk.TaskSupport do
  @moduledoc false

  alias CliSubprocessCore.TaskSupport, as: CoreTaskSupport

  @default_supervisor AmpSdk.TaskSupervisor

  @type task_start_error ::
          :noproc | {:task_start_failed, term()} | {:application_start_failed, term()}

  @spec start_child((-> any())) :: {:ok, pid()} | {:error, task_start_error()}
  def start_child(fun) when is_function(fun, 0) do
    start_child(@default_supervisor, fun)
  end

  @spec start_child(pid() | atom(), (-> any())) :: {:ok, pid()} | {:error, task_start_error()}
  def start_child(supervisor, fun) when is_function(fun, 0) do
    with :ok <- ensure_started_for(supervisor) do
      CoreTaskSupport.start_child(supervisor, fun)
    end
  end

  @spec async_nolink((-> any())) :: {:ok, Task.t()} | {:error, task_start_error()}
  def async_nolink(fun) when is_function(fun, 0) do
    async_nolink(@default_supervisor, fun)
  end

  @spec async_nolink(pid() | atom(), (-> any())) :: {:ok, Task.t()} | {:error, task_start_error()}
  def async_nolink(supervisor, fun) when is_function(fun, 0) do
    with :ok <- ensure_started_for(supervisor) do
      CoreTaskSupport.async_nolink(supervisor, fun)
    end
  end

  defp ensure_started_for(@default_supervisor) do
    case Application.ensure_all_started(:amp_sdk) do
      {:ok, _started_apps} -> :ok
      {:error, reason} -> {:error, {:application_start_failed, reason}}
    end
  end

  defp ensure_started_for(_supervisor), do: :ok
end
