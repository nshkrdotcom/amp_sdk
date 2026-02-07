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
  |> Enum.find_value(fn
    %AmpSdk.Types.SystemMessage{session_id: id} -> id
    _ -> nil
  end)

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
