# Thread handoff and replay
# Run with: mix run examples/threads_handoff_replay.exs

alias AmpSdk.Types.Options

IO.puts("=== Thread Handoff & Replay ===\n")

# Create a thread with content so handoff/replay have something to work with
IO.puts("Creating thread with content...")

thread_id =
  AmpSdk.execute("Reply with only: hello", %Options{
    dangerously_allow_all: true,
    visibility: "private"
  })
  |> Enum.find_value(fn
    %AmpSdk.Types.SystemMessage{session_id: id} -> id
    _ -> nil
  end)

IO.puts("Thread: #{thread_id}")

# Handoff
IO.puts("\nHandoff:")

case AmpSdk.threads_handoff(thread_id) do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, e} -> IO.puts("  Error: #{inspect(e)}")
end

# Replay
IO.puts("\nReplay:")

case AmpSdk.threads_replay(thread_id) do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, e} -> IO.puts("  Error: #{inspect(e)}")
end

# Cleanup
AmpSdk.threads_delete(thread_id)

System.halt(0)
