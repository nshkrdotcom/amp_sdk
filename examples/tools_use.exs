# Invoke a tool directly
# Run with: mix run examples/tools_use.exs

IO.puts("=== Tools Use ===\n")

case AmpSdk.tools_use("Read",
       only: "content",
       args: [path: Path.expand("mix.exs"), read_range: [1, 5]],
       timeout: 30_000
     ) do
  {:ok, output} ->
    lines = output |> String.split("\n", trim: true) |> Enum.take(5) |> Enum.join("\n")
    IO.puts("Read mix.exs (first 5 lines):\n#{lines}")

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
