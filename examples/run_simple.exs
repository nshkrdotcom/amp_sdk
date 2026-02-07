# Simplified execution - just get the final result
#
# Run with: mix run examples/run_simple.exs

alias AmpSdk.Types.Options

IO.puts("=== AmpSdk Simple Run ===\n")

case AmpSdk.run("What is 2 + 2? Reply with only the number.", %Options{
       dangerously_allow_all: true
     }) do
  {:ok, result} ->
    IO.puts("Result: #{result}")

  {:error, %AmpSdk.Error{kind: kind, message: message}} ->
    IO.puts("Error [#{kind}]: #{message}")
end

System.halt(0)
