# List installed skills
# Run with: mix run examples/skills_list.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== Skills ===\n")

case Support.invoke(["skill", "list"]) do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
