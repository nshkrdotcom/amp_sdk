defmodule AmpSdk.MCP do
  @moduledoc "MCP server management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error}
  alias AmpSdk.Types.MCPServer

  @spec add(String.t(), String.t() | [String.t()], keyword()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def add(name, command_or_url, opts \\ [])

  def add(name, url, opts) when is_binary(name) and is_binary(url) and is_list(opts) do
    args =
      ["mcp", "add", name]
      |> maybe_append_workspace(opts)
      |> append_kv_flags("--header", opts[:header])
      |> Kernel.++([url])

    CLIInvoke.invoke(args, opts)
  end

  def add(name, [command | args], opts) when is_binary(name) and is_list(opts) do
    base =
      ["mcp", "add", name]
      |> maybe_append_workspace(opts)
      |> append_kv_flags("--env", opts[:env])

    CLIInvoke.invoke(base ++ ["--", command | args], opts)
  end

  @spec list(keyword()) :: {:ok, [MCPServer.t()]} | {:error, Error.t()}
  def list(opts \\ []) when is_list(opts) do
    args = ["mcp", "list", "--json"]

    with {:ok, output} <- CLIInvoke.invoke(args, opts),
         {:ok, decoded} <- decode_json_list(output, "MCP"),
         {:ok, servers} <- parse_servers(decoded) do
      {:ok, servers}
    end
  end

  @spec list_raw(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def list_raw(opts \\ []) when is_list(opts) do
    CLIInvoke.invoke(["mcp", "list"], opts)
  end

  @spec remove(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def remove(name) when is_binary(name) do
    CLIInvoke.invoke(["mcp", "remove", name])
  end

  @spec doctor() :: {:ok, String.t()} | {:error, Error.t()}
  def doctor do
    CLIInvoke.invoke(["mcp", "doctor"])
  end

  @spec approve(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def approve(name) when is_binary(name) do
    CLIInvoke.invoke(["mcp", "approve", name])
  end

  @spec oauth_login(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def oauth_login(server_name, opts \\ []) when is_binary(server_name) do
    args = ["mcp", "oauth", "login", server_name]
    args = if opts[:server_url], do: args ++ ["--server-url", opts[:server_url]], else: args
    args = if opts[:client_id], do: args ++ ["--client-id", opts[:client_id]], else: args

    args =
      if opts[:client_secret], do: args ++ ["--client-secret", opts[:client_secret]], else: args

    args = if opts[:scopes], do: args ++ ["--scopes", opts[:scopes]], else: args
    args = if opts[:auth_url], do: args ++ ["--auth-url", opts[:auth_url]], else: args
    args = if opts[:token_url], do: args ++ ["--token-url", opts[:token_url]], else: args

    CLIInvoke.invoke(args, opts)
  end

  @spec oauth_logout(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def oauth_logout(server_name, opts \\ []) when is_binary(server_name) do
    CLIInvoke.invoke(["mcp", "oauth", "logout", server_name], opts)
  end

  @spec oauth_status(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def oauth_status(server_name, opts \\ []) when is_binary(server_name) do
    CLIInvoke.invoke(["mcp", "oauth", "status", server_name], opts)
  end

  defp maybe_append_workspace(args, opts) do
    if opts[:workspace], do: args ++ ["--workspace"], else: args
  end

  defp append_kv_flags(args, _flag, nil), do: args

  defp append_kv_flags(args, flag, kvs) when is_map(kvs),
    do: append_kv_flags(args, flag, Map.to_list(kvs))

  defp append_kv_flags(args, flag, kvs) when is_list(kvs) do
    Enum.reduce(kvs, args, fn
      {key, value}, acc when not is_nil(value) ->
        acc ++ [flag, "#{key}=#{value}"]

      _, acc ->
        acc
    end)
  end

  defp append_kv_flags(args, _flag, _), do: args

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

  defp parse_servers(decoded) when is_list(decoded) do
    Enum.reduce_while(decoded, {:ok, []}, fn server, {:ok, acc} ->
      case parse_server(server) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, servers} -> {:ok, Enum.reverse(servers)}
      error -> error
    end
  end

  defp parse_server(server) when is_map(server) do
    name = fetch(server, [:name, "name"]) || "unknown"
    type = fetch(server, [:type, "type"]) || "unknown"
    source = fetch(server, [:source, "source"]) || "unknown"

    {:ok,
     %MCPServer{
       name: to_string(name),
       type: to_string(type),
       source: to_string(source),
       command: normalize_optional_string(fetch(server, [:command, "command"])),
       args: normalize_args(fetch(server, [:args, "args"])),
       url: normalize_optional_string(fetch(server, [:url, "url"])),
       raw: server
     }}
  end

  defp parse_server(server) do
    {:error,
     Error.new(:parse_error, "Failed to parse MCP list output",
       context: %{reason: :non_map_entry, value: inspect(server)}
     )}
  end

  defp fetch(map, [key | rest]) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> fetch(map, rest)
    end
  end

  defp fetch(_map, []), do: nil

  defp normalize_optional_string(nil), do: nil
  defp normalize_optional_string(value), do: to_string(value)

  defp normalize_args(args) when is_list(args), do: Enum.map(args, &to_string/1)
  defp normalize_args(_), do: []
end
