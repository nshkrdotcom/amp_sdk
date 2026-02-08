defmodule AmpSdk.Tasks do
  @moduledoc "Task management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error}

  @spec list() :: {:ok, String.t()} | {:error, Error.t()}
  def list do
    CLIInvoke.invoke(["tasks", "list"])
  end

  @spec import_tasks(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def import_tasks(json_file, opts \\ [])
      when is_binary(json_file) and is_list(opts) do
    args = ["tasks", "import", json_file]
    args = if opts[:repo], do: args ++ ["--repo", opts[:repo]], else: args
    args = if opts[:dry_run], do: args ++ ["--dry-run"], else: args
    args = if opts[:force], do: args ++ ["--force"], else: args

    CLIInvoke.invoke(args, opts)
  end
end
