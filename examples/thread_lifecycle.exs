# Thread lifecycle: create, rename, share, archive, delete
# Run with: mix run examples/thread_lifecycle.exs

alias AmpSdk.Types.Options

IO.puts("=== Thread Lifecycle ===\n")

# Create a thread with content (rename requires non-empty thread)
IO.puts("Creating thread with content...")

thread_id =
  AmpSdk.execute("Reply with only: lifecycle test", %Options{
    dangerously_allow_all: true,
    visibility: "private"
  })
  # Consume the full stream before mutating the thread, otherwise the thread can
  # still be empty when lifecycle commands run.
  |> Enum.reduce(nil, fn
    %AmpSdk.Types.SystemMessage{session_id: id}, _acc -> id
    _msg, acc -> acc
  end)

if is_nil(thread_id) do
  IO.puts("Failed to capture thread id from stream output.")
  System.halt(1)
end

IO.puts("Created:  #{thread_id}")

# Rename
case AmpSdk.threads_rename(thread_id, "SDK lifecycle test") do
  {:ok, _} -> IO.puts("Renamed:  OK")
  {:error, e} -> IO.puts("Rename:   #{inspect(e)}")
end

# Share (set visibility to public)
case AmpSdk.threads_share(thread_id, visibility: :public) do
  {:ok, output} -> IO.puts("Shared:   #{String.trim(output)}")
  {:error, e} -> IO.puts("Share:    #{inspect(e)}")
end

# Archive (soft-delete)
case AmpSdk.threads_archive(thread_id) do
  {:ok, _} -> IO.puts("Archived: OK")
  {:error, e} -> IO.puts("Archive:  #{inspect(e)}")
end

# Delete (permanent)
case AmpSdk.threads_delete(thread_id) do
  {:ok, _} -> IO.puts("Deleted:  OK")
  {:error, e} -> IO.puts("Delete:   #{inspect(e)}")
end

IO.puts("\nLifecycle complete.")
System.halt(0)
