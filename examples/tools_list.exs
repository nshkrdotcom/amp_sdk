# List all available tools
# Run with: mix run examples/tools_list.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== Tools List ===\n")
{:ok, output} = Support.invoke(["tools", "list"])
IO.puts(output)
System.halt(0)
