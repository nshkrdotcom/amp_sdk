# Search threads by query
# Run with: mix run examples/threads_search.exs

IO.puts("=== Thread Search ===\n")

case AmpSdk.threads_search("elixir", limit: 5) do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("No results or error: #{inspect(err)}")
end

System.halt(0)
