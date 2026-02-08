defmodule AmpSdk.Permissions do
  @moduledoc "Permission management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error}
  alias AmpSdk.Types.PermissionRule

  @spec list(keyword()) :: {:ok, [PermissionRule.t()]} | {:error, Error.t()}
  def list(opts \\ []) when is_list(opts) do
    args =
      ["permissions", "list"]
      |> maybe_append_flag(opts[:builtin], "--builtin")
      |> maybe_append_flag(opts[:workspace], "--workspace")
      |> Kernel.++(["--json"])

    with {:ok, output} <- CLIInvoke.invoke(args, opts),
         {:ok, decoded} <- decode_json_list(output, "permissions"),
         {:ok, rules} <- parse_rules(decoded) do
      {:ok, rules}
    end
  end

  @spec list_raw(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def list_raw(opts \\ []) when is_list(opts) do
    args =
      ["permissions", "list"]
      |> maybe_append_flag(opts[:builtin], "--builtin")
      |> maybe_append_flag(opts[:workspace], "--workspace")

    CLIInvoke.invoke(args, opts)
  end

  @spec test(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def test(tool_name, opts \\ []) when is_binary(tool_name) do
    args = ["permissions", "test", tool_name]

    tool_args = Keyword.get(opts, :args, [])

    args =
      Enum.reduce(tool_args, args, fn
        {key, value}, acc -> acc ++ ["--#{key}", to_string(value)]
      end)

    CLIInvoke.invoke(args, opts)
  end

  @spec add(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def add(tool, action, opts \\ []) when is_binary(tool) and is_binary(action) do
    args = ["permissions", "add", action, tool]
    args = if opts[:context], do: args ++ ["--context", to_string(opts[:context])], else: args
    args = if opts[:to], do: args ++ ["--to", to_string(opts[:to])], else: args
    args = if opts[:workspace], do: args ++ ["--workspace"], else: args

    CLIInvoke.invoke(args, opts)
  end

  defp decode_json_list(output, label) do
    case Jason.decode(output) do
      {:ok, decoded} when is_list(decoded) ->
        {:ok, decoded}

      {:ok, other} ->
        {:error,
         Error.new(:parse_error, "Failed to decode #{label} list JSON",
           details: output,
           context: %{reason: :json_not_list, value: inspect(other)}
         )}

      {:error, reason} ->
        {:error,
         Error.new(:parse_error, "Failed to decode #{label} list JSON",
           cause: reason,
           details: output
         )}
    end
  end

  defp parse_rules(decoded) when is_list(decoded) do
    Enum.reduce_while(decoded, {:ok, []}, fn rule, {:ok, acc} ->
      case parse_rule(rule) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, rules} -> {:ok, Enum.reverse(rules)}
      error -> error
    end
  end

  defp parse_rule(rule) when is_map(rule) do
    tool = fetch(rule, [:tool, "tool"])
    action = fetch(rule, [:action, "action"])

    if is_binary(tool) and is_binary(action) do
      {:ok,
       %PermissionRule{
         tool: tool,
         action: action,
         context: fetch(rule, [:context, "context"]),
         to: fetch(rule, [:to, "to"]),
         matches: fetch(rule, [:matches, "matches"]),
         raw: rule
       }}
    else
      {:error,
       Error.new(:parse_error, "Failed to parse permissions list output",
         context: %{reason: :missing_required_fields, value: inspect(rule)}
       )}
    end
  end

  defp parse_rule(rule) do
    {:error,
     Error.new(:parse_error, "Failed to parse permissions list output",
       context: %{reason: :non_map_entry, value: inspect(rule)}
     )}
  end

  defp fetch(map, [key | rest]) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> fetch(map, rest)
    end
  end

  defp fetch(_map, []), do: nil

  defp maybe_append_flag(args, true, flag), do: args ++ [flag]
  defp maybe_append_flag(args, _value, _flag), do: args
end
