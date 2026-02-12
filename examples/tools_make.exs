# Create a new tool
# Run with: mix run examples/tools_make.exs

IO.puts("=== Tools Make ===\n")

create_tool = fn create_tool, attempt ->
  suffix = Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  tool_name = "amp-sdk-test-tool-#{System.system_time(:microsecond)}-#{suffix}"

  case AmpSdk.tools_make(tool_name, timeout: 8_000) do
    {:ok, output} ->
      {:ok, tool_name, output}

    {:error, %AmpSdk.Error{kind: :command_timeout}} ->
      {:skip, "Skipping tools_make: this CLI version appears interactive in headless mode."}

    {:error, %AmpSdk.Error{} = err} ->
      details = err.details

      if attempt < 3 and is_binary(details) and String.contains?(details, "already exists") do
        create_tool.(create_tool, attempt + 1)
      else
        {:error, err}
      end

    {:error, err} ->
      {:error, err}
  end
end

case create_tool.(create_tool, 1) do
  {:ok, tool_name, output} ->
    IO.puts("Created tool '#{tool_name}':\n#{output}")

  {:skip, message} ->
    IO.puts(message)
    System.halt(20)

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
    System.halt(1)
end

System.halt(0)
