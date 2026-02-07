# Multi-turn conversation using thread continuation
# Run with: mix run examples/continue_thread.exs

alias AmpSdk.Types.Options

IO.puts("=== Thread Continuation ===\n")

IO.puts("Turn 1: Setting context...")

case AmpSdk.run("Remember the number 42. Reply with: OK, remembered.", %Options{
       dangerously_allow_all: true,
       visibility: "private"
     }) do
  {:ok, r} -> IO.puts("  #{r}")
  {:error, e} -> IO.puts("  Error: #{inspect(e)}")
end

IO.puts("\nTurn 2: Recalling context...")

case AmpSdk.run("What number did I ask you to remember? Reply with only the number.", %Options{
       continue_thread: true,
       dangerously_allow_all: true
     }) do
  {:ok, r} -> IO.puts("  #{r}")
  {:error, e} -> IO.puts("  Error: #{inspect(e)}")
end

System.halt(0)
