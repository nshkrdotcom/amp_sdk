# Create a new tool
# Run with: mix run examples/tools_make.exs

IO.puts("=== Tools Make ===\n")

tool_name = "amp-sdk-test-tool-#{System.unique_integer([:positive])}"

case AmpSdk.tools_make(tool_name, timeout: 8_000) do
  {:ok, output} ->
    IO.puts("Created tool '#{tool_name}':\n#{output}")

  {:error, %AmpSdk.Error{kind: :command_timeout}} ->
    IO.puts("Skipping tools_make: this CLI version appears interactive in headless mode.")
    System.halt(20)

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
    System.halt(1)
end

System.halt(0)
