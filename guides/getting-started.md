# Getting Started

## Prerequisites

1. **Elixir 1.14+** and **OTP 26+**
2. **Amp CLI** installed and authenticated

### Install the Amp CLI

```bash
curl -fsSL https://ampcode.com/install.sh | bash
```

Or via npm:

```bash
npm install -g @sourcegraph/amp
```

### Authenticate

```bash
amp login
```

Or set the `AMP_API_KEY` environment variable.

## Add to Your Project

```elixir
# mix.exs
def deps do
  [
    {:amp_sdk, "~> 0.3.1"}
  ]
end
```

```bash
mix deps.get
```

## Your First Query

The simplest way to use the SDK is `AmpSdk.run/2`, which sends a prompt and returns the final result:

```elixir
{:ok, result} = AmpSdk.run("What files are in this directory?")
IO.puts(result)
```

## Streaming Responses

For real-time output, use `AmpSdk.execute/2` which returns a lazy `Stream`:

```elixir
alias AmpSdk.Types.{AssistantMessage, ResultMessage, SystemMessage, TextContent}

"Explain the architecture of this project"
|> AmpSdk.execute()
|> Enum.each(fn
  %SystemMessage{tools: tools} ->
    IO.puts("Session started with #{length(tools)} tools")

  %AssistantMessage{message: %{content: content}} ->
    for %TextContent{text: text} <- content, do: IO.write(text)

  %ResultMessage{duration_ms: ms} ->
    IO.puts("\nDone in #{ms}ms")

  _ -> :ok
end)
```

## Configuration

All options are passed via `AmpSdk.Types.Options`:

```elixir
alias AmpSdk.Types.Options

AmpSdk.run("Review this code", %Options{
  mode: "smart",
  visibility: "private",
  dangerously_allow_all: true
})
```

See the [Configuration](configuration.md) guide for all available options.

## Next Steps

- [Configuration](configuration.md) — all options, modes, and environment variables
- [Streaming](streaming.md) — real-time output and message types
- [Permissions](permissions.md) — control which tools Amp can use
- [Threads](threads.md) — multi-turn conversations and thread management
- [Error Handling](error-handling.md) — error kinds and recovery patterns
- [Testing](testing.md) — testing strategies for SDK-dependent code
- [Tools & Management](tools-and-management.md) — tools, tasks, review, skills, MCP, usage
