defmodule AmpSdk.Tasks do
  @moduledoc "Task management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error}

  @spec list() :: {:ok, String.t()} | {:error, Error.t()}
  def list do
    CLIInvoke.invoke(["tasks", "list"])
  end

  @spec import_tasks(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def import_tasks(json_file) when is_binary(json_file) do
    CLIInvoke.invoke(["tasks", "import", json_file])
  end
end
