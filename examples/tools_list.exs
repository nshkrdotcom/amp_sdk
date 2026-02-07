# List all available tools
# Run with: mix run examples/tools_list.exs

IO.puts("=== Tools List ===\n")
{:ok, output} = AmpSdk.tools_list()
IO.puts(output)
System.halt(0)
