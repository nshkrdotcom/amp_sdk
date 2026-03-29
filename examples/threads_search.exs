# Search threads by query
# Run with: mix run examples/threads_search.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== Thread Search ===\n")

case AmpSdk.threads_search("elixir", Support.command_opts(limit: 5)) do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("No results or error: #{inspect(err)}")
end

System.halt(0)
