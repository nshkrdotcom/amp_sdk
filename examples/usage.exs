# Show current usage and credit balance
# Run with: mix run examples/usage.exs

IO.puts("=== Usage ===\n")
{:ok, output} = AmpSdk.usage()
IO.puts(output)
System.halt(0)
