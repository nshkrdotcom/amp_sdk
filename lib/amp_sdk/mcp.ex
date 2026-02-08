defmodule AmpSdk.MCP do
  @moduledoc "MCP server management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error}

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

  @spec list(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def list(opts \\ []) when is_list(opts) do
    args = if opts[:json], do: ["mcp", "list", "--json"], else: ["mcp", "list"]
    CLIInvoke.invoke(args, opts)
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
end
