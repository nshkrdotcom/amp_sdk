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
  # Consume the full stream before using the thread so it is fully persisted.
  |> Enum.reduce(nil, fn
    %AmpSdk.Types.SystemMessage{session_id: id}, _acc -> id
    _msg, acc -> acc
  end)

if is_nil(thread_id) do
  IO.puts("Failed to capture thread id from stream output.")
  System.halt(1)
end

IO.puts("Thread: #{thread_id}")

failed = false

# Handoff
IO.puts("\nHandoff:")

failed =
  case AmpSdk.threads_handoff(thread_id,
         goal: "Continue this thread and summarize the current state in one sentence.",
         print: true
       ) do
    {:ok, output} ->
      IO.puts("  #{String.trim(output)}")
      failed

    {:error, e} ->
      IO.puts("  Error: #{inspect(e)}")
      true
  end

# Replay
IO.puts("\nReplay:")

failed =
  if System.get_env("AMP_RUN_REPLAY", "0") == "1" do
    case AmpSdk.threads_replay(thread_id, no_typing: true, no_indicator: true, exit_delay: 0) do
      {:ok, output} ->
        IO.puts("  #{String.trim(output)}")
        failed

      {:error, e} ->
        IO.puts("  Error: #{inspect(e)}")
        true
    end
  else
    IO.puts("  Skipped replay. Set AMP_RUN_REPLAY=1 to run interactive replay.")
    failed
  end

# Cleanup
AmpSdk.threads_delete(thread_id)

if failed, do: System.halt(1), else: System.halt(0)
