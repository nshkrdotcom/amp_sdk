# Thread management example
#
# Run with: mix run examples/threads.exs

IO.puts("=== AmpSdk Threads ===\n")

case AmpSdk.threads_new(visibility: :private) do
  {:ok, thread_id} ->
    IO.puts("Created thread: #{thread_id}")

    case AmpSdk.threads_markdown(thread_id) do
      {:ok, markdown} ->
        IO.puts("\nThread markdown:\n#{markdown}")

      {:error, %AmpSdk.Error{kind: kind, message: message}} ->
        IO.puts("Failed to get markdown [#{kind}]: #{message}")
    end

  {:error, %AmpSdk.Error{kind: kind, message: message}} ->
    IO.puts("Failed to create thread [#{kind}]: #{message}")
end

System.halt(0)
