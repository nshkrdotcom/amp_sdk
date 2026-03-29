# Show details for a specific tool
# Run with: mix run examples/tools_show.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== Tool: Read ===\n")
{:ok, output} = Support.invoke(["tools", "show", "Read"])
IO.puts(output)
System.halt(0)
