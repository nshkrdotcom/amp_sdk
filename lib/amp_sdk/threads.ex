defmodule AmpSdk.Threads do
  @moduledoc "Thread management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error, Util}
  alias AmpSdk.Types.ThreadSummary

  @type visibility :: :private | :public | :workspace | :group
  @thread_row_regex ~r/^(?<title>.*?)\s{2,}(?<last_updated>.*?)\s{2,}(?<visibility>[A-Za-z]+)\s{2,}(?<messages>\d+)\s{2,}(?<id>T-[A-Za-z0-9-]+)\s*$/

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

  @spec list(keyword()) :: {:ok, [ThreadSummary.t()]} | {:error, Error.t()}
  def list(opts \\ []) when is_list(opts) do
    with {:ok, output} <- CLIInvoke.invoke(["threads", "list"], opts) do
      parse_list_output(output)
    end
  end

  @spec list_raw(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def list_raw(opts \\ []) when is_list(opts) do
    CLIInvoke.invoke(["threads", "list"], opts)
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

  defp parse_list_output(output) do
    lines =
      output
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim_trailing/1)
      |> Enum.reject(&(&1 == ""))

    cond do
      lines == [] ->
        {:ok, []}

      no_records_line?(hd(lines)) ->
        {:ok, []}

      true ->
        lines
        |> drop_table_header()
        |> Enum.reject(&separator_line?/1)
        |> parse_rows(output)
    end
  end

  defp parse_rows([], _raw_output), do: {:ok, []}

  defp parse_rows(rows, raw_output) do
    Enum.reduce_while(rows, {:ok, []}, fn row, {:ok, acc} ->
      case parse_row(row) do
        {:ok, parsed} ->
          {:cont, {:ok, [parsed | acc]}}

        {:error, %Error{} = error} ->
          {:halt,
           {:error,
            Error.normalize(error,
              kind: :parse_error,
              details: raw_output,
              context: Map.put(error.context, :row, row)
            )}}
      end
    end)
    |> case do
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      error -> error
    end
  end

  defp parse_row(row) when is_binary(row) do
    case Regex.named_captures(@thread_row_regex, row) do
      %{
        "id" => id,
        "last_updated" => last_updated,
        "messages" => messages,
        "title" => title,
        "visibility" => visibility
      } ->
        {:ok,
         %ThreadSummary{
           id: String.trim(id),
           title: String.trim(title),
           last_updated: String.trim(last_updated),
           visibility: parse_visibility(visibility),
           messages: String.to_integer(messages),
           raw: row
         }}

      _ ->
        {:error,
         Error.new(:parse_error, "Failed to parse thread list output",
           context: %{reason: :unmatched_row}
         )}
    end
  end

  defp drop_table_header([header, separator | rows]) do
    if String.contains?(header, "Thread ID") and separator_line?(separator),
      do: rows,
      else: [header, separator | rows]
  end

  defp drop_table_header(rows), do: rows

  defp separator_line?(line) when is_binary(line) do
    stripped = line |> String.replace(" ", "")
    stripped != "" and Regex.match?(~r/^[^[:alnum:]]+$/, stripped)
  end

  defp no_records_line?(line) when is_binary(line) do
    line
    |> String.trim()
    |> String.downcase()
    |> String.starts_with?("no ")
  end

  defp parse_visibility(visibility) when is_binary(visibility) do
    case visibility |> String.trim() |> String.downcase() do
      "private" -> :private
      "public" -> :public
      "workspace" -> :workspace
      "group" -> :group
      _ -> :unknown
    end
  end
end
