# MCP OAuth operations
# Run with: mix run examples/mcp_oauth.exs

IO.puts("=== MCP OAuth ===\n")

server_name = System.get_env("AMP_MCP_OAUTH_SERVER")
server_url = System.get_env("AMP_MCP_OAUTH_SERVER_URL")
timeout_ms = String.to_integer(System.get_env("AMP_MCP_OAUTH_TIMEOUT_MS", "15000"))

if is_nil(server_name) or is_nil(server_url) or String.trim(server_name) == "" or
     String.trim(server_url) == "" do
  IO.puts("Skipping MCP OAuth example. Set AMP_MCP_OAUTH_SERVER and AMP_MCP_OAUTH_SERVER_URL.")
  System.halt(20)
end

IO.puts("Checking OAuth status for '#{server_name}':")

case AmpSdk.mcp_oauth_status(server_name, timeout: timeout_ms) do
  {:ok, output} ->
    IO.puts("  #{String.trim(output)}")

  {:error, err} ->
    IO.puts("  Error: #{inspect(err)}")
    System.halt(1)
end

IO.puts("\nOAuth logout for '#{server_name}':")

case AmpSdk.mcp_oauth_logout(server_name, timeout: timeout_ms) do
  {:ok, output} ->
    IO.puts("  #{String.trim(output)}")

  {:error, err} ->
    IO.puts("  Error: #{inspect(err)}")
    System.halt(1)
end

# OAuth login requires browser interaction.
IO.puts("\nOAuth login for '#{server_name}':")

maybe_put_env_opt = fn opts, env_key, opt_key ->
  case System.get_env(env_key) do
    nil -> opts
    value when is_binary(value) and value != "" -> Keyword.put(opts, opt_key, value)
    _ -> opts
  end
end

login_opts =
  []
  |> Keyword.put(:server_url, server_url)
  |> Keyword.put(:timeout, timeout_ms)
  |> maybe_put_env_opt.("AMP_MCP_OAUTH_CLIENT_ID", :client_id)
  |> maybe_put_env_opt.("AMP_MCP_OAUTH_CLIENT_SECRET", :client_secret)
  |> maybe_put_env_opt.("AMP_MCP_OAUTH_SCOPES", :scopes)
  |> maybe_put_env_opt.("AMP_MCP_OAUTH_AUTH_URL", :auth_url)
  |> maybe_put_env_opt.("AMP_MCP_OAUTH_TOKEN_URL", :token_url)

if System.get_env("AMP_MCP_OAUTH_RUN_LOGIN", "0") == "1" do
  case AmpSdk.mcp_oauth_login(server_name, login_opts) do
    {:ok, output} ->
      IO.puts("  #{String.trim(output)}")

    {:error, err} ->
      IO.puts("  Error: #{inspect(err)}")
      System.halt(1)
  end
else
  IO.puts("  Skipped login. Set AMP_MCP_OAUTH_RUN_LOGIN=1 to run browser-based login.")
end

System.halt(0)
