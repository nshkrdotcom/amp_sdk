# Import tasks from a JSON file
# Run with: mix run examples/tasks_import.exs

IO.puts("=== Tasks Import ===\n")

# Create a temp tasks file — use --dry-run to validate without persisting
tasks = %{
  "tasks" => [
    %{
      "title" => "SDK example task",
      "description" => "Created by tasks_import.exs example",
      "repo" => "https://github.com/example/repo"
    }
  ]
}

tmp_path = Path.join(System.tmp_dir!(), "amp_sdk_example_tasks.json")
File.write!(tmp_path, Jason.encode!(tasks))
IO.puts("Wrote tasks to: #{tmp_path}")

# Use dry-run to validate without creating tasks
case AmpSdk.tasks_import(tmp_path, dry_run: true) do
  {:ok, output} -> IO.puts("Import result:\n#{output}")
  {:error, err} -> IO.puts("Error (may require valid repo URL): #{inspect(err)}")
end

File.rm(tmp_path)
System.halt(0)
