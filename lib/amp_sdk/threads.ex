defmodule AmpSdk.Threads do
  @moduledoc "Thread management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error, Util}

  @type visibility :: :private | :public | :workspace | :group

  @spec new(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def new(opts \\ []) do
    visibility = Keyword.get(opts, :visibility)

    args = ["threads", "new"]
    args = if visibility, do: args ++ ["--visibility", to_string(visibility)], else: args

    CLIInvoke.invoke(args, opts)
  end

  @spec markdown(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def markdown(thread_id) when is_binary(thread_id) do
    CLIInvoke.invoke(["threads", "markdown", thread_id])
  end

  @spec list() :: {:ok, String.t()} | {:error, Error.t()}
  def list do
    CLIInvoke.invoke(["threads", "list"])
  end

  @spec search(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def search(query, opts \\ []) when is_binary(query) do
    args = ["threads", "search", query]
    args = if opts[:limit], do: args ++ ["--limit", to_string(opts[:limit])], else: args
    args = if opts[:offset], do: args ++ ["--offset", to_string(opts[:offset])], else: args
    args = if opts[:json], do: args ++ ["--json"], else: args

    CLIInvoke.invoke(args, opts)
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

    CLIInvoke.invoke(args, opts)
  end

  @spec rename(String.t(), String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def rename(thread_id, name) when is_binary(thread_id) and is_binary(name) do
    CLIInvoke.invoke(["threads", "rename", thread_id, name])
  end

  @spec archive(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def archive(thread_id) when is_binary(thread_id) do
    CLIInvoke.invoke(["threads", "archive", thread_id])
  end

  @spec delete(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def delete(thread_id) when is_binary(thread_id) do
    CLIInvoke.invoke(["threads", "delete", thread_id])
  end

  @spec handoff(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def handoff(thread_id, opts \\ []) when is_binary(thread_id) and is_list(opts) do
    args = ["threads", "handoff", thread_id]
    args = if opts[:goal], do: args ++ ["--goal", opts[:goal]], else: args
    args = if opts[:print], do: args ++ ["--print"], else: args

    run_opts =
      opts
      |> Keyword.take([:timeout, :stdin])
      |> Util.maybe_put_kw(:stdin, Keyword.get(opts, :input))

    CLIInvoke.invoke(args, run_opts)
  end

  @spec replay(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def replay(thread_id, opts \\ []) when is_binary(thread_id) and is_list(opts) do
    args =
      ["threads", "replay", thread_id]
      |> Util.maybe_append(opts[:wpm], ["--wpm", to_string(opts[:wpm] || "")])
      |> Util.maybe_append(opts[:no_typing], ["--no-typing"])
      |> Util.maybe_append(opts[:message_delay], [
        "--message-delay",
        to_string(opts[:message_delay] || "")
      ])
      |> Util.maybe_append(opts[:tool_progress_delay], [
        "--tool-progress-delay",
        to_string(opts[:tool_progress_delay] || "")
      ])
      |> Util.maybe_append(opts[:exit_delay], ["--exit-delay", to_string(opts[:exit_delay] || "")])
      |> Util.maybe_append(opts[:no_indicator], ["--no-indicator"])

    args
    |> CLIInvoke.invoke(opts)
    |> maybe_wrap_replay_error(thread_id)
  end

  defp maybe_wrap_replay_error(
         {:error, %Error{kind: :command_failed, details: details} = error},
         thread_id
       ) do
    details = to_string(details || "")

    if String.contains?(details, "Unexpected error inside Amp CLI.") do
      {:error,
       Error.new(
         :command_execution_failed,
         "threads replay requires an interactive terminal; run `amp threads replay #{thread_id}` directly",
         cause: error,
         details: details
       )}
    else
      {:error, error}
    end
  end

  defp maybe_wrap_replay_error(result, _thread_id), do: result
end
