# List all threads
# Run with: mix run examples/threads_list.exs

IO.puts("=== Thread List ===\n")
{:ok, output} = AmpSdk.threads_list()
IO.puts(String.slice(output, 0, 2000))
System.halt(0)
