# Show current usage and credit balance
# Run with: mix run examples/usage.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== Usage ===\n")
{:ok, output} = Support.invoke(["usage"])
IO.puts(output)
System.halt(0)
