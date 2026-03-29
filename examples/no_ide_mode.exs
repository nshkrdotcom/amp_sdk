# Execute with IDE integration disabled
# Run with: mix run examples/no_ide_mode.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias AmpSdk.Types.Options
alias Examples.Support

Support.init!()

IO.puts("=== No-IDE Mode ===\n")

case AmpSdk.run(
       "Reply with only: headless",
       %Options{
         no_ide: true,
         no_notifications: true,
         no_color: true,
         dangerously_allow_all: true
       }
       |> Support.with_execution_surface()
     ) do
  {:ok, result} -> IO.puts("Result: #{result}")
  {:error, err} -> IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
