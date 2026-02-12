# Threads

Threads provide conversation continuity across multiple Amp executions. Each execution creates a thread, and you can continue threads to build multi-step workflows.

## Creating Threads

```elixir
{:ok, thread_id} = AmpSdk.threads_new(visibility: :private)
# => {:ok, "T-a1b2c3d4-..."}
```

### Visibility Options

- `:private` — only you can see it
- `:public` — anyone with the link
- `:workspace` — workspace members
- `:group` — group members

## Continuing Threads

### Continue Most Recent Thread

```elixir
alias AmpSdk.Types.Options

AmpSdk.run("Follow up on the last task", %Options{continue_thread: true})
```

### Continue a Specific Thread

```elixir
AmpSdk.run("Continue this work", %Options{continue_thread: "T-abc123-def456"})
```

## Listing Threads

```elixir
{:ok, threads} = AmpSdk.threads_list()

Enum.each(threads, fn thread ->
  IO.puts("#{thread.id} #{thread.visibility} #{thread.messages} #{thread.title}")
end)
```

## Searching Threads

```elixir
# Basic search
{:ok, results} = AmpSdk.threads_search("auth refactor")

# With pagination
{:ok, results} = AmpSdk.threads_search("auth", limit: 10, offset: 0)

# JSON output for programmatic use
{:ok, json} = AmpSdk.threads_search("auth", json: true)
```

## Sharing Threads

Change visibility or share with Amp support:

```elixir
# Change thread visibility
{:ok, output} = AmpSdk.threads_share("T-abc123-def456", visibility: :public)
IO.puts(output)

# Share with Amp support for debugging
{:ok, output} = AmpSdk.threads_share("T-abc123-def456", support: true)
IO.puts(output)
```

## Renaming Threads

```elixir
{:ok, _} = AmpSdk.threads_rename("T-abc123-def456", "Auth module refactor")
```

## Archiving Threads

Soft-delete a thread (can be restored):

```elixir
{:ok, _} = AmpSdk.threads_archive("T-abc123-def456")
```

## Deleting Threads

Permanently delete a thread:

```elixir
{:ok, _} = AmpSdk.threads_delete("T-abc123-def456")
```

## Handoff Threads

Create a handoff thread from an existing thread for multi-agent workflows:

```elixir
{:ok, new_thread_id} = AmpSdk.threads_handoff("T-abc123-def456",
  goal: "Continue with the auth refactor and summarize next steps",
  print: true
)
```

## Replaying Threads

Re-run a thread with its original history:

```elixir
{:ok, output} = AmpSdk.threads_replay("T-abc123-def456",
  no_typing: true,
  no_indicator: true,
  exit_delay: 0
)
```

`threads_replay` is terminal-driven by the Amp CLI; in some non-interactive/headless
environments the CLI may return an internal error.

## Exporting Threads

Get a thread's conversation as Markdown:

```elixir
{:ok, markdown} = AmpSdk.threads_markdown("T-abc123-def456")
File.write!("thread_export.md", markdown)
```

## Multi-Step Workflow

```elixir
alias AmpSdk.Types.Options

opts = %Options{visibility: "private", dangerously_allow_all: true}

# Step 1: Analyze
{:ok, analysis} = AmpSdk.run("Analyze lib/auth.ex for improvements", opts)

# Step 2: Implement (continues the thread)
{:ok, changes} = AmpSdk.run(
  "Implement the improvements you identified",
  %Options{opts | continue_thread: true}
)

# Step 3: Test (continues again)
{:ok, tests} = AmpSdk.run(
  "Write tests for the changes",
  %Options{opts | continue_thread: true}
)
```

## Session ID

Each execution's `SystemMessage` includes a `session_id` (the thread ID). You can capture it from the stream:

```elixir
thread_id =
  AmpSdk.execute("Hello")
  # Drain the stream fully so the thread is persisted before follow-up commands.
  |> Enum.reduce(nil, fn
    %AmpSdk.Types.SystemMessage{session_id: id}, _acc -> id
    _msg, acc -> acc
  end)
```

## All Thread Functions

| Function | Description |
|---|---|
| `threads_new/1` | Create a new thread (opts: `visibility`) |
| `threads_list/0` | List all threads as typed `%ThreadSummary{}` structs |
| `threads_search/2` | Search threads (opts: `limit`, `offset`, `json`) |
| `threads_share/2` | Share a thread (opts: `visibility`, `support`) |
| `threads_rename/2` | Rename a thread |
| `threads_archive/1` | Archive (soft-delete) a thread |
| `threads_delete/1` | Permanently delete a thread |
| `threads_handoff/2` | Create a handoff thread (opts: `goal`, `print`, `input`, `timeout`) |
| `threads_replay/2` | Replay a thread (opts: `wpm`, `no_typing`, `message_delay`, `tool_progress_delay`, `exit_delay`, `no_indicator`) |
| `threads_markdown/1` | Export thread as Markdown |
