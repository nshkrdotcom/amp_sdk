# Execute with IDE integration disabled
# Run with: mix run examples/no_ide_mode.exs

alias AmpSdk.Types.Options

IO.puts("=== No-IDE Mode ===\n")

case AmpSdk.run("Reply with only: headless", %Options{
       no_ide: true,
       no_notifications: true,
       no_color: true,
       dangerously_allow_all: true
     }) do
  {:ok, result} -> IO.puts("Result: #{result}")
  {:error, err} -> IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
