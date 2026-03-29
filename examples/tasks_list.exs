# List tasks
# Run with: mix run examples/tasks_list.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== Tasks ===\n")

case Support.invoke(["tasks", "list"]) do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("No tasks or error: #{inspect(err)}")
end

System.halt(0)
