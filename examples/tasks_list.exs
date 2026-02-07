# List tasks
# Run with: mix run examples/tasks_list.exs

IO.puts("=== Tasks ===\n")

case AmpSdk.tasks_list() do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("No tasks or error: #{inspect(err)}")
end

System.halt(0)
