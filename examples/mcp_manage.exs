# MCP server lifecycle: add, approve, remove
# Run with: mix run examples/mcp_manage.exs

IO.puts("=== MCP Manage ===\n")

server_name = "amp-sdk-test-echo"

# Add a local MCP server (stdio)
IO.puts("Adding MCP server '#{server_name}':")

case AmpSdk.mcp_add(server_name, ["echo", "hello"], env: %{}) do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, err} -> IO.puts("  Error: #{inspect(err)}")
end

# Approve the server
IO.puts("\nApproving:")

case AmpSdk.mcp_approve(server_name) do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, err} -> IO.puts("  Error: #{inspect(err)}")
end

# Remove the server (cleanup)
IO.puts("\nRemoving:")

case AmpSdk.mcp_remove(server_name) do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, err} -> IO.puts("  Error: #{inspect(err)}")
end

System.halt(0)
