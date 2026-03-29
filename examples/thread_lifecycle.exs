# Thread lifecycle: create, rename, share, archive, delete
# Run with: mix run examples/thread_lifecycle.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias AmpSdk.Types.Options
alias Examples.Support

Support.init!()

IO.puts("=== Thread Lifecycle ===\n")

# Create a thread with content (rename requires non-empty thread)
IO.puts("Creating thread with content...")

thread_id =
  AmpSdk.execute(
    "Reply with only: lifecycle test",
    %Options{
      dangerously_allow_all: true,
      visibility: "private"
    }
    |> Support.with_execution_surface()
  )
  # Consume the full stream before mutating the thread, otherwise the thread can
  # still be empty when lifecycle commands run.
  |> Enum.reduce(nil, fn message, acc ->
    case AmpSdk.Types.session_id(message) do
      nil -> acc
      id -> id
    end
  end)

if is_nil(thread_id) do
  IO.puts("Failed to capture thread id from stream output.")
  System.halt(1)
end

IO.puts("Created:  #{thread_id}")

# Rename
case Support.invoke(["threads", "rename", thread_id, "SDK lifecycle test"]) do
  {:ok, _} -> IO.puts("Renamed:  OK")
  {:error, e} -> IO.puts("Rename:   #{inspect(e)}")
end

# Share (set visibility to public)
case AmpSdk.threads_share(thread_id, Support.command_opts(visibility: :public)) do
  {:ok, output} -> IO.puts("Shared:   #{String.trim(output)}")
  {:error, e} -> IO.puts("Share:    #{inspect(e)}")
end

# Archive (soft-delete)
case Support.invoke(["threads", "archive", thread_id]) do
  {:ok, _} -> IO.puts("Archived: OK")
  {:error, e} -> IO.puts("Archive:  #{inspect(e)}")
end

# Delete (permanent)
case Support.invoke(["threads", "delete", thread_id]) do
  {:ok, _} -> IO.puts("Deleted:  OK")
  {:error, e} -> IO.puts("Delete:   #{inspect(e)}")
end

IO.puts("\nLifecycle complete.")
System.halt(0)
