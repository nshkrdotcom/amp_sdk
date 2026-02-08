# List all threads
# Run with: mix run examples/threads_list.exs

IO.puts("=== Thread List ===\n")

case AmpSdk.threads_list() do
  {:ok, threads} ->
    IO.puts("Found #{length(threads)} thread(s)\n")

    threads
    |> Enum.take(20)
    |> Enum.each(fn thread ->
      IO.puts(
        "#{thread.id}  #{thread.visibility}  messages=#{thread.messages}  #{thread.last_updated}  #{thread.title}"
      )
    end)

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
    System.halt(1)
end

System.halt(0)
