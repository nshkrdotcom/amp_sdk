# MCP OAuth operations
# Run with: mix run examples/mcp_oauth.exs

IO.puts("=== MCP OAuth ===\n")

server_name = System.get_env("AMP_MCP_OAUTH_SERVER", "example-server")

IO.puts("Checking OAuth status for '#{server_name}':")

case AmpSdk.mcp_oauth_status(server_name) do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, err} -> IO.puts("  Error: #{inspect(err)}")
end

IO.puts("\nOAuth logout for '#{server_name}':")

case AmpSdk.mcp_oauth_logout(server_name) do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, err} -> IO.puts("  Error: #{inspect(err)}")
end

# OAuth login requires a browser — skip in headless, just exercise the function
IO.puts("\nOAuth login for '#{server_name}':")

case AmpSdk.mcp_oauth_login(server_name, timeout: 5_000) do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, err} -> IO.puts("  Error: #{inspect(err)}")
end

System.halt(0)
