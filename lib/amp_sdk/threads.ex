defmodule AmpSdk.Threads do
  @moduledoc "Thread management via the Amp CLI."

  alias AmpSdk.{CommandRunner, Error}

  @type visibility :: :private | :public | :workspace | :group

  @spec new(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def new(opts \\ []) do
    visibility = Keyword.get(opts, :visibility)

    args = ["threads", "new"]
    args = if visibility, do: args ++ ["--visibility", to_string(visibility)], else: args

    CommandRunner.run(args, Keyword.take(opts, [:timeout]))
  end

  @spec markdown(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def markdown(thread_id) when is_binary(thread_id) do
    CommandRunner.run(["threads", "markdown", thread_id])
  end

  @spec list() :: {:ok, String.t()} | {:error, Error.t()}
  def list do
    CommandRunner.run(["threads", "list"])
  end

  @spec search(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def search(query, opts \\ []) when is_binary(query) do
    args = ["threads", "search", query]
    args = if opts[:limit], do: args ++ ["--limit", to_string(opts[:limit])], else: args
    args = if opts[:offset], do: args ++ ["--offset", to_string(opts[:offset])], else: args
    args = if opts[:json], do: args ++ ["--json"], else: args

    CommandRunner.run(args, Keyword.take(opts, [:timeout]))
  end

  @spec share(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def share(thread_id, opts \\ []) when is_binary(thread_id) do
    visibility = Keyword.get(opts, :visibility)
    support = Keyword.get(opts, :support)

    args = ["threads", "share", thread_id]
    args = if visibility, do: args ++ ["--visibility", to_string(visibility)], else: args

    args =
      case support do
        true -> args ++ ["--support"]
        msg when is_binary(msg) -> args ++ ["--support", msg]
        _ -> args
      end

    CommandRunner.run(args, Keyword.take(opts, [:timeout]))
  end

  @spec rename(String.t(), String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def rename(thread_id, name) when is_binary(thread_id) and is_binary(name) do
    CommandRunner.run(["threads", "rename", thread_id, name])
  end

  @spec archive(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def archive(thread_id) when is_binary(thread_id) do
    CommandRunner.run(["threads", "archive", thread_id])
  end

  @spec delete(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def delete(thread_id) when is_binary(thread_id) do
    CommandRunner.run(["threads", "delete", thread_id])
  end

  @spec handoff(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def handoff(thread_id) when is_binary(thread_id) do
    CommandRunner.run(["threads", "handoff", thread_id])
  end

  @spec replay(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def replay(thread_id) when is_binary(thread_id) do
    CommandRunner.run(["threads", "replay", thread_id])
  end
end
