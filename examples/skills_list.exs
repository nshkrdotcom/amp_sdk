# List installed skills
# Run with: mix run examples/skills_list.exs

IO.puts("=== Skills ===\n")

case AmpSdk.skills_list() do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
