# Create a new tool (interactive — may fail in headless mode)
# Run with: mix run examples/tools_make.exs

IO.puts("=== Tools Make ===\n")

# tools make is interactive (prompts for tool definition), so it will
# typically fail or timeout when run headlessly. We exercise the code path
# and handle the expected error gracefully.
case AmpSdk.tools_make("amp-sdk-test-tool") do
  {:ok, output} ->
    IO.puts("Created tool:\n#{output}")

  {:error, err} ->
    IO.puts("Expected error (interactive command): #{inspect(err)}")
end

System.halt(0)
