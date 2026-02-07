# List configured MCP servers
# Run with: mix run examples/mcp_list.exs

IO.puts("=== MCP Servers ===\n")

case AmpSdk.mcp_list() do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
