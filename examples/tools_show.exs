# Show details for a specific tool
# Run with: mix run examples/tools_show.exs

IO.puts("=== Tool: Read ===\n")
{:ok, output} = AmpSdk.tools_show("Read")
IO.puts(output)
System.halt(0)
