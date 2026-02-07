# Check MCP server health
# Run with: mix run examples/mcp_doctor.exs

IO.puts("=== MCP Doctor ===\n")

case AmpSdk.mcp_doctor() do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
