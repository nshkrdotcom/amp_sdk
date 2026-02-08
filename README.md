<p align="center">
  <img src="assets/amp_sdk.svg" alt="Amp SDK for Elixir" width="200" height="200">
</p>

# Amp SDK for Elixir

[![Elixir](https://img.shields.io/badge/elixir-1.14+-purple.svg)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/otp-26+-blue.svg)](https://www.erlang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/amp_sdk.svg)](https://hex.pm/packages/amp_sdk)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/amp_sdk)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/nshkrdotcom/amp_sdk/blob/main/LICENSE)

An idiomatic Elixir SDK for [Amp](https://ampcode.com) (by Sourcegraph) -- the agentic coding assistant. Wraps the Amp CLI with streaming JSON output, multi-turn conversations, thread management, MCP server integration, and fine-grained permission control.

> **Note:** This SDK requires the Amp CLI to be installed on the host machine. The SDK communicates with Amp exclusively through its `--execute --stream-json` interface -- no direct API calls are made.

---

## What You Can Build

- Automated code review and refactoring pipelines
- CI/CD integrations that use Amp to fix failing tests or lint issues
- Multi-agent orchestration with Amp as a coding sub-agent
- Chat interfaces backed by Amp's coding capabilities
- Batch processing across repositories with thread continuity
- Custom developer tools with approval hooks and permission policies

---

## Installation

Add `amp_sdk` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:amp_sdk, "~> 0.1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

---

## Prerequisites

### Amp CLI

Install the Amp CLI binary:

```bash
curl -fsSL https://ampcode.com/install.sh | bash
```

Or via npm:

```bash
npm install -g @sourcegraph/amp
```

Verify the installation:

```bash
amp --version
```

### Authentication

Log in to your Amp account (required for execution):

```bash
amp login
```

Or set the `AMP_API_KEY` environment variable:

```bash
export AMP_API_KEY=your-api-key
```

### CLI Discovery

The SDK locates the Amp CLI automatically by checking, in order:

| Priority | Method | Details |
|---|---|---|
| 1 | `AMP_CLI_PATH` env var | Explicit path override (supports `.js` files via Node) |
| 2 | `~/.amp/bin/amp` | Official binary install location |
| 3 | `~/.local/bin/amp` | Symlink from install script |
| 4 | System `PATH` | Standard executable lookup |
| 5 | Node.js `require.resolve` | Legacy npm global install |

---

## Quick Start

### 1. Run a Simple Query

```elixir
{:ok, result} = AmpSdk.run("What files are in this directory?")
IO.puts(result)
```

`AmpSdk.run/2` blocks until the agent finishes, returning the final result text.

### 2. Stream Responses in Real Time

```elixir
alias AmpSdk.Types.{AssistantMessage, ResultMessage, SystemMessage}

"Explain the architecture of this project"
|> AmpSdk.execute()
|> Enum.each(fn
  %SystemMessage{tools: tools} ->
    IO.puts("Session started with #{length(tools)} tools")

  %AssistantMessage{message: %{content: content}} ->
    for %{type: "text", text: text} <- content do
      IO.write(text)
    end

  %ResultMessage{result: result, duration_ms: ms, num_turns: turns} ->
    IO.puts("\n--- Done in #{ms}ms (#{turns} turns) ---")

  _other ->
    :ok
end)
```

`AmpSdk.execute/2` returns a lazy `Stream` -- messages arrive as the agent works, and the stream halts automatically when a result or error is received.

### 3. Continue a Thread

```elixir
alias AmpSdk.Types.Options

# First interaction
"Add input validation to the User module"
|> AmpSdk.execute(%Options{visibility: "private"})
|> Enum.each(&handle_message/1)

# Continue the same thread
"Now add tests for the validation we just added"
|> AmpSdk.execute(%Options{continue_thread: true})
|> Enum.each(&handle_message/1)

# Or continue a specific thread by ID
"Review the changes"
|> AmpSdk.execute(%Options{continue_thread: "T-abc123-def456"})
|> Enum.each(&handle_message/1)
```

---

## Core API

### `AmpSdk.execute/2`

Streams messages from the Amp agent as a lazy `Enumerable`.

```elixir
@spec execute(String.t() | [AmpSdk.Types.UserInputMessage.t() | map()], Options.t()) ::
        Enumerable.t(stream_message())
```

Messages are yielded in order as the agent works:

1. `SystemMessage` -- session init with available tools and MCP server status
2. `AssistantMessage` -- agent responses (text blocks and/or tool calls)
3. `UserMessage` -- tool results fed back to the agent
4. `ResultMessage` or `ErrorResultMessage` -- final outcome (stream halts)

### `AmpSdk.run/2`

Convenience wrapper that collects the stream and returns the final result:

```elixir
@spec run(String.t(), Options.t()) :: {:ok, String.t()} | {:error, AmpSdk.Error.t()}

{:ok, answer} = AmpSdk.run("How many modules are in lib/?")
{:error, reason} = AmpSdk.run("Do something impossible")
```

### `AmpSdk.create_user_message/1`

Creates a `UserInputMessage` struct for JSON-input streaming:

```elixir
msgs = [
  AmpSdk.create_user_message("Summarize the last change and suggest next steps.")
]

msgs
|> AmpSdk.execute()
|> Enum.to_list()
```

### `AmpSdk.create_permission/3`

Creates a `Permission` struct for tool access control:

```elixir
perm = AmpSdk.create_permission("Bash", "allow")
perm = AmpSdk.create_permission("Bash", "delegate", to: "bash -c")
perm = AmpSdk.create_permission("Read", "ask", matches: %{"path" => "/secret/*"})
```

### `AmpSdk.threads_new/1` and `AmpSdk.threads_markdown/1`

Manage threads directly:

```elixir
{:ok, thread_id} = AmpSdk.threads_new(visibility: :private)
{:ok, markdown}   = AmpSdk.threads_markdown(thread_id)
```

---

## Configuration Options

All execution behavior is controlled through `AmpSdk.Types.Options`:

```elixir
%AmpSdk.Types.Options{
  cwd: "/path/to/project",           # Working directory (default: cwd)
  mode: "smart",                      # Agent mode (see table below)
  dangerously_allow_all: false,       # Skip all permission prompts
  visibility: "workspace",            # Thread visibility
  continue_thread: nil,               # true | "thread-id" | nil
  settings_file: nil,                 # Path to settings.json
  log_level: nil,                     # "debug" | "info" | "warn" | "error" | "audit"
  log_file: nil,                      # Log file path
  env: %{},                           # Extra environment variables
  mcp_config: nil,                    # MCP server configuration (map or JSON string)
  toolbox: nil,                       # Path to toolbox scripts
  skills: nil,                        # Path to custom skills
  permissions: nil,                   # List of Permission structs
  labels: nil,                        # Thread labels (max 20, alphanumeric + hyphens)
  thinking: false,                    # Use --stream-json-thinking when prompt is a string
  stream_timeout_ms: 300_000,         # Receive timeout for stream events
  no_ide: false,                      # Disable IDE context injection
  no_notifications: false,            # Disable notification sounds
  no_color: false,                    # Disable ANSI colors
  no_jetbrains: false                 # Disable JetBrains integration
}
```

### Agent Modes

| Mode | SDK Compatible | Description |
|---|---|---|
| `"smart"` | Yes | Default balanced mode |
| `"rush"` | No | Faster execution (CLI-only, no `--stream-json` support) |
| `"deep"` | No | More thorough analysis (CLI-only, no `--stream-json` support) |
| `"free"` | No | Interactive-only (incompatible with `--execute`) |

> **Note:** Only `"smart"` mode supports `--stream-json`, which the SDK requires. Other modes can only be used via the CLI directly.

### Thread Visibility

| Visibility | Description |
|---|---|
| `"private"` | Only visible to the creator |
| `"public"` | Visible to anyone with the link |
| `"workspace"` | Visible to workspace members (default) |
| `"group"` | Visible to group members |

---

## Permissions

Fine-grained control over which tools the agent can use:

```elixir
alias AmpSdk.Types.{Options, Permission}

permissions = [
  # Allow file reads without prompting
  AmpSdk.create_permission("Read", "allow"),

  # Ask before running shell commands
  AmpSdk.create_permission("Bash", "ask"),

  # Block file deletion entirely
  AmpSdk.create_permission("Bash", "reject",
    matches: %{"cmd" => ["rm *", "rmdir *"]}
  ),

  # Only ask in subagent context
  AmpSdk.create_permission("edit_file", "ask", context: "subagent")
]

"Refactor the auth module"
|> AmpSdk.execute(%Options{permissions: permissions, dangerously_allow_all: false})
|> Enum.each(&handle_message/1)
```

### Permission Actions

| Action | Behavior |
|---|---|
| `"allow"` | Permit tool use without prompting |
| `"reject"` | Block tool use silently |
| `"ask"` | Prompt user before allowing (headless mode: deny) |
| `"delegate"` | Run a different command instead (requires `:to` option) |

Permissions are written to a temporary `settings.json` that is passed to the CLI via `--settings-file` and cleaned up after execution.

---

## MCP Server Integration

Configure [Model Context Protocol](https://modelcontextprotocol.io/) servers to extend the agent's capabilities:

```elixir
alias AmpSdk.Types.Options

# Stdio-based MCP server
mcp_config = %{
  "filesystem" => %{
    "command" => "npx",
    "args" => ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
    "env" => %{}
  }
}

"List all markdown files using the filesystem MCP tool"
|> AmpSdk.execute(%Options{mcp_config: mcp_config})
|> Enum.each(&handle_message/1)

# HTTP-based MCP server
mcp_config = %{
  "remote-api" => %{
    "url" => "https://api.example.com/mcp",
    "headers" => %{"Authorization" => "Bearer token"}
  }
}
```

MCP server connection status is reported in the initial `SystemMessage`:

```elixir
%SystemMessage{mcp_servers: [%{name: "filesystem", status: "connected"}]}
```

Possible statuses: `"awaiting-approval"`, `"authenticating"`, `"connecting"`, `"reconnecting"`, `"connected"`, `"denied"`, `"failed"`, `"blocked-by-registry"`.

---

## Thread Management

Threads persist conversation history on Amp's servers. Use them for multi-step workflows:

```elixir
# Create a new thread
{:ok, thread_id} = AmpSdk.threads_new(visibility: :private)

# Run against it
"Analyze the codebase"
|> AmpSdk.execute(%Options{continue_thread: thread_id})
|> Enum.each(&handle_message/1)

# Continue the same thread later
"Now implement the changes we discussed"
|> AmpSdk.execute(%Options{continue_thread: thread_id})
|> Enum.each(&handle_message/1)

# Export conversation as markdown
{:ok, md} = AmpSdk.threads_markdown(thread_id)
File.write!("thread_export.md", md)
```

---

## Stream Message Types

Every message from `execute/2` is one of these structs:

### `SystemMessage`

First message in every session. Contains session metadata.

```elixir
%SystemMessage{
  type: "system",
  subtype: "init",
  session_id: "T-...",
  cwd: "/path/to/project",
  tools: ["Bash", "Read", "edit_file", "glob", ...],
  mcp_servers: [%MCPServerStatus{name: "fs", status: "connected"}]
}
```

### `AssistantMessage`

Agent responses. Content is a list of text blocks and/or tool calls.

```elixir
%AssistantMessage{
  type: "assistant",
  session_id: "T-...",
  message: %{
    role: "assistant",
    model: "claude-sonnet-4-5-20250929",
    content: [
      %TextContent{type: "text", text: "I'll read the file..."},
      %ToolUseContent{type: "tool_use", id: "tu_1", name: "Read", input: %{"path" => "lib/app.ex"}}
    ],
    stop_reason: "tool_use",
    usage: %Usage{input_tokens: 1024, output_tokens: 256, ...}
  }
}
```

### `UserMessage`

Tool results fed back to the agent automatically.

```elixir
%UserMessage{
  type: "user",
  message: %{
    role: "user",
    content: [
      %ToolResultContent{type: "tool_result", tool_use_id: "tu_1", content: "...", is_error: false}
    ]
  }
}
```

### `ResultMessage`

Successful completion. Includes total usage and timing.

```elixir
%ResultMessage{
  type: "result",
  subtype: "success",
  is_error: false,
  result: "I've updated the module with...",
  duration_ms: 12450,
  num_turns: 3,
  usage: %Usage{input_tokens: 8192, output_tokens: 2048},
  permission_denials: nil
}
```

### `ErrorResultMessage`

Execution failed or hit max turns.

```elixir
%ErrorResultMessage{
  type: "result",
  subtype: "error_during_execution",  # or "error_max_turns"
  is_error: true,
  error: "Failed to complete the task",
  duration_ms: 5000,
  num_turns: 1,
  permission_denials: ["Bash: rm -rf /"]
}
```

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  AmpSdk (Public API)                 │
│                                                      │
│  execute/2 ── stream messages from agent             │
│  run/2     ── blocking call, returns final result    │
│  threads_*/N wrappers for thread lifecycle ops        │
│  create_permission/3, create_user_message/1          │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│             AmpSdk.Stream (Stream Engine)            │
│                                                      │
│  - Builds CLI args from Options struct               │
│  - Creates temp settings.json for permissions/skills │
│  - Wraps execution as Stream.resource/3              │
│  - Parses JSON lines into typed structs              │
│  - Halts on ResultMessage / ErrorResultMessage       │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│     AmpSdk.Transport.Erlexec (GenServer + erlexec)   │
│                                                      │
│  - Spawns `amp --execute --stream-json` subprocess   │
│  - Manages stdin/stdout/stderr via erlexec           │
│  - Splits stdout into JSON lines                     │
│  - Broadcasts lines to subscribers via messages      │
│  - Handles buffer overflow, process exit, cleanup    │
└──────────────────────┬───────────────────────────────┘
                       │
               ┌───────▼───────┐
               │   Amp CLI     │
               │  (headless)   │
               └───────────────┘
```

### Module Overview

| Module | Purpose |
|---|---|
| `AmpSdk` | Public API -- `execute/2`, `run/2`, delegation helpers |
| `AmpSdk.Stream` | Stream engine -- builds args, manages lifecycle, parses output |
| `AmpSdk.Transport` | Behaviour defining the subprocess communication contract |
| `AmpSdk.Transport.Erlexec` | GenServer implementation using erlexec for process management |
| `AmpSdk.CLI` | CLI binary discovery across multiple install methods |
| `AmpSdk.Threads` | Thread lifecycle management wrappers over CLI commands |
| `AmpSdk.Types` | All structs: messages, content blocks, options, permissions, MCP config |
| `AmpSdk.Error` | Unified error envelope used by tuple-based APIs |
| `AmpSdk.Errors` | Legacy/specialized exception types: `AmpError`, `CLINotFoundError`, `ProcessError`, `JSONParseError` |

---

## Error Handling

`AmpSdk.run/2` is tuple-based and returns `%AmpSdk.Error{}` on failures:

```elixir
case AmpSdk.run("do something") do
  {:ok, result} ->
    IO.puts(result)

  {:error, %AmpSdk.Error{kind: :no_result}} ->
    IO.puts("No result received")

  {:error, %AmpSdk.Error{kind: kind, message: message}} ->
    IO.puts("#{kind}: #{message}")
end
```

Exceptional conditions (for example invalid settings JSON) can still raise typed errors such as `AmpSdk.Errors.AmpError`.

Internal timeout/task helpers also normalize into `%AmpSdk.Error{}` kinds (for example `:task_timeout`).

Streaming failures are surfaced inline as `ErrorResultMessage` structs:

```elixir
"bad prompt"
|> AmpSdk.execute()
|> Enum.each(fn
  %ErrorResultMessage{error: error, permission_denials: denials} ->
    IO.puts("Error: #{error}")
    if denials, do: IO.puts("Denied: #{inspect(denials)}")

  _msg -> :ok
end)
```

Low-level transport APIs (`AmpSdk.Transport.Erlexec`) return tagged tuples like `{:error, {:transport, reason}}`; use `AmpSdk.Transport.error_to_error/2` (or `AmpSdk.Error.normalize/2`) when you want the unified envelope there as well.

---

## Environment Variables

| Variable | Purpose |
|---|---|
| `AMP_CLI_PATH` | Override CLI binary path |
| `AMP_API_KEY` | Amp authentication key |
| `AMP_URL` | Override Amp service endpoint (default: `https://ampcode.com/`) |
| `AMP_TOOLBOX` | Path to toolbox scripts (also settable via `Options.toolbox`) |
| `AMP_SDK_VERSION` | SDK identifier sent to CLI (auto-set to `elixir-<current package version>`) |

`AmpSdk.run/2` and `AmpSdk.execute/2` use the same CLI env builder: base system keys (`PATH`, `HOME`, etc.), `AMP_*` keys, `Options.env` overrides, and automatic `AMP_SDK_VERSION` tagging.

Additional env vars can be passed per-execution via `Options.env`:

```elixir
AmpSdk.run("check env", %Options{env: %{"MY_VAR" => "value"}})
```

For MCP config constructors, conflicting atom/string versions of the same key are rejected as `:invalid_configuration` to avoid ambiguous input maps.

---

## Examples

### Mix Task

```elixir
# lib/mix/tasks/amp.ex
defmodule Mix.Tasks.Amp do
  use Mix.Task

  @shortdoc "Run an Amp query against the current project"

  def run([prompt | _]) do
    Mix.Task.run("app.start")

    case AmpSdk.run(prompt) do
      {:ok, result} -> Mix.shell().info(result)
      {:error, %AmpSdk.Error{kind: kind, message: message}} ->
        Mix.shell().error("[#{kind}] #{message}")
    end
  end
end
```

```bash
mix amp "What does this project do?"
```

### Streaming with Progress

```elixir
alias AmpSdk.Types.{AssistantMessage, ResultMessage, ErrorResultMessage, SystemMessage}

defmodule MyApp.AmpRunner do
  def run_with_progress(prompt, opts \\ %AmpSdk.Types.Options{}) do
    prompt
    |> AmpSdk.execute(opts)
    |> Enum.reduce(%{text: "", turns: 0}, fn
      %SystemMessage{session_id: id, tools: tools}, acc ->
        IO.puts("[session #{id}] #{length(tools)} tools available")
        acc

      %AssistantMessage{message: %{content: content}}, acc ->
        text = content
          |> Enum.filter(&match?(%{type: "text"}, &1))
          |> Enum.map(& &1.text)
          |> Enum.join()
        IO.write(text)
        %{acc | text: acc.text <> text}

      %ResultMessage{duration_ms: ms, num_turns: turns}, acc ->
        IO.puts("\nCompleted in #{ms}ms (#{turns} turns)")
        %{acc | turns: turns}

      %ErrorResultMessage{error: error}, acc ->
        IO.puts("\nError: #{error}")
        acc

      _, acc -> acc
    end)
  end
end
```

### Automated Code Review

```elixir
alias AmpSdk.Types.Options

permissions = [
  AmpSdk.create_permission("Read", "allow"),
  AmpSdk.create_permission("glob", "allow"),
  AmpSdk.create_permission("Grep", "allow"),
  AmpSdk.create_permission("Bash", "reject"),
  AmpSdk.create_permission("edit_file", "reject"),
  AmpSdk.create_permission("create_file", "reject")
]

{:ok, review} = AmpSdk.run(
  "Review the code in lib/ for bugs, security issues, and style problems. Be thorough.",
  %Options{
    mode: "smart",
    permissions: permissions,
    visibility: "private"
  }
)

IO.puts(review)
```

### Multi-Step Workflow with Thread Continuity

```elixir
alias AmpSdk.Types.Options

opts = %Options{visibility: "private", dangerously_allow_all: true}

# Step 1: Analyze
{:ok, analysis} = AmpSdk.run("Analyze lib/my_app/auth.ex for improvements", opts)
IO.puts(analysis)

# Step 2: Implement (same thread)
{:ok, changes} = AmpSdk.run(
  "Implement the improvements you identified",
  %Options{opts | continue_thread: true}
)
IO.puts(changes)

# Step 3: Test
{:ok, tests} = AmpSdk.run(
  "Write tests for the changes you made",
  %Options{opts | continue_thread: true}
)
IO.puts(tests)
```

---

## Documentation

Full API documentation is available on [HexDocs](https://hexdocs.pm/amp_sdk).

### Guides

- [Getting Started](guides/getting-started.md) — installation, authentication, first query
- [Configuration](guides/configuration.md) — all options, modes, MCP, environment variables
- [Streaming](guides/streaming.md) — message types, real-time output patterns
- [Permissions](guides/permissions.md) — tool access control and safety
- [Threads](guides/threads.md) — multi-turn conversations and thread management
- [Error Handling](guides/error-handling.md) — exception types and recovery
- [Testing](guides/testing.md) — unit and integration testing strategies

### Examples

See [examples/](examples/README.md) for runnable scripts. Run all with:

```bash
./examples/run_all.sh
```

### Generate Docs Locally

```bash
mix docs
open doc/index.html
```

---

## License

MIT -- see [LICENSE](LICENSE) for details.

---

## Acknowledgments

- [Sourcegraph](https://sourcegraph.com) for the [Amp](https://ampcode.com) coding agent and CLI
- [Sasa Juric](https://github.com/sasa1977) for [erlexec](https://github.com/saleyn/erlexec), the backbone of subprocess management
- Built to complement [claude_agent_sdk](https://github.com/nshkrdotcom/claude_agent_sdk) and [codex_sdk](https://github.com/nshkrdotcom/codex_sdk) for multi-agent Elixir workflows

---

## Related Projects

| Project | Description |
|---|---|
| [claude_agent_sdk](https://github.com/nshkrdotcom/claude_agent_sdk) | Elixir SDK for Claude Code (Anthropic) |
| [codex_sdk](https://github.com/nshkrdotcom/codex_sdk) | Elixir SDK for Codex (OpenAI) |
| [amp-sdk (Python)](https://pypi.org/project/amp-sdk/) | Official Python SDK by Sourcegraph |
| [Amp CLI](https://ampcode.com) | The Amp coding agent |
