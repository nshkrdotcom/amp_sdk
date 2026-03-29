# Check MCP server health
# Run with: mix run examples/mcp_doctor.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== MCP Doctor ===\n")

case Support.invoke(["mcp", "doctor"]) do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
