# Configuration

All execution behavior is controlled through the `AmpSdk.Types.Options` struct.

## Options Reference

| Field | Type | Default | Description |
|---|---|---|---|
| `cwd` | `String.t()` | `File.cwd!()` | Working directory for the Amp agent |
| `mode` | `String.t()` | `"smart"` | Agent mode (see below) |
| `dangerously_allow_all` | `boolean()` | `false` | Skip all permission prompts |
| `visibility` | `String.t()` | `"workspace"` | Thread visibility |
| `continue_thread` | `boolean \| String.t()` | `nil` | Continue a thread |
| `settings_file` | `String.t()` | `nil` | Path to settings.json |
| `log_level` | `String.t()` | `nil` | Log level for the CLI |
| `log_file` | `String.t()` | `nil` | Log output file path |
| `env` | `map()` | `%{}` | Extra environment variables |
| `mcp_config` | `map() \| String.t()` | `nil` | MCP server configuration |
| `toolbox` | `String.t()` | `nil` | Path to toolbox scripts |
| `skills` | `String.t()` | `nil` | Path to custom skills |
| `permissions` | `[Permission.t()]` | `nil` | Permission rules |
| `labels` | `[String.t()]` | `nil` | Thread labels (max 20) |
| `thinking` | `boolean()` | `false` | Use `--stream-json-thinking` for string prompts |
| `stream_timeout_ms` | `pos_integer()` | `300_000` | Stream receive timeout in milliseconds |
| `no_ide` | `boolean()` | `false` | Disable IDE context injection (`--no-ide`) |
| `no_notifications` | `boolean()` | `false` | Disable sound notifications (`--no-notifications`) |
| `no_color` | `boolean()` | `false` | Disable ANSI colors (`--no-color`) |
| `no_jetbrains` | `boolean()` | `false` | Disable JetBrains integration (`--no-jetbrains`) |

## Agent Modes

| Mode | SDK Compatible | Description |
|---|---|---|
| `"smart"` | Yes | Default — balanced model and tool selection |
| `"rush"` | No | Faster execution, incompatible with `--stream-json` |
| `"deep"` | No | Thorough analysis, incompatible with `--stream-json` |
| `"free"` | No | Interactive-only, incompatible with `--execute` |

> **Important:** Only `"smart"` mode supports `--stream-json`, which the SDK uses for both `execute/2` and `run/2`. The other modes (`rush`, `deep`) are only usable via the CLI directly (for example `amp --mode deep --execute "prompt"` without `--stream-json`). `"free"` mode is interactive-only and cannot be used programmatically at all. This is a CLI restriction, not an SDK limitation.

```elixir
# Default smart mode (the only mode that works with the SDK)
AmpSdk.execute("Explain this code") |> Enum.each(&handle/1)
{:ok, result} = AmpSdk.run("Explain this code")
```

`mode` is passed through to the installed Amp CLI. Supported values may change as Amp evolves.

## Thread Visibility

| Value | Description |
|---|---|
| `"private"` | Only you can see the thread |
| `"public"` | Anyone with the link can view |
| `"workspace"` | Visible to workspace members |
| `"group"` | Visible to group members |

## Thread Continuation

```elixir
# Continue the most recent thread
AmpSdk.run("Follow up", %Options{continue_thread: true})

# Continue a specific thread
AmpSdk.run("Follow up", %Options{continue_thread: "T-abc123"})
```

## MCP Server Configuration

Pass MCP server configs as a map:

```elixir
mcp = %{
  "filesystem" => %{
    "command" => "npx",
    "args" => ["-y", "@modelcontextprotocol/server-filesystem"],
    "env" => %{}
  }
}

AmpSdk.run("List files", %Options{mcp_config: mcp})
```

## Environment Variables

| Variable | Purpose |
|---|---|
| `AMP_CLI_PATH` | Override CLI binary path |
| `AMP_API_KEY` | Amp authentication key |
| `AMP_URL` | Override Amp service endpoint (default: `https://ampcode.com/`) |
| `AMP_TOOLBOX` | Path to toolbox scripts |
| `AMP_SDK_VERSION` | SDK identifier (auto-set to `elixir-<current package version>`) |
| `AMP_LOG_LEVEL` | Log level (alternative to `--log-level` flag) |
| `AMP_LOG_FILE` | Log file path (alternative to `--log-file` flag) |
| `AMP_SETTINGS_FILE` | Settings file path (alternative to `--settings-file` flag) |

All `AMP_`-prefixed environment variables are automatically forwarded to the CLI subprocess.
`AmpSdk.run/2` and `AmpSdk.execute/2` now share the same environment construction path, including automatic `AMP_SDK_VERSION` injection.

Additional env vars per execution:

```elixir
AmpSdk.run("check env", %Options{env: %{"MY_VAR" => "value"}})
```

## Headless Flags

Control IDE, notification, color, and JetBrains integration:

```elixir
AmpSdk.run("task", %Options{
  no_ide: true,            # --no-ide (disable IDE file inclusion)
  no_notifications: true,  # --no-notifications (silence sounds)
  no_color: true,          # --no-color (plain text output)
  no_jetbrains: true       # --no-jetbrains (disable JetBrains)
})
```

These default to `false`. Set to `true` for headless/CI environments.

## Option Key Normalization

When building MCP structs from maps/keywords, avoid mixing atom and string forms of the same key with different values.

```elixir
# Invalid: conflicting values for the same key
AmpSdk.Types.MCPStdioServer.new(%{command: "npx", "command" => "node"})
```

Conflicts are rejected with `{:error, %AmpSdk.Error{kind: :invalid_configuration}}` to prevent ambiguous configuration.

## Thinking Mode

Include the model's chain-of-thought reasoning in responses:

```elixir
AmpSdk.execute("Explain this code", %Options{thinking: true})
|> Enum.each(fn
  %AmpSdk.Types.AssistantMessage{message: %{content: content}} ->
    for %AmpSdk.Types.ThinkingContent{thinking: t} <- content, do: IO.puts("[think] #{t}")
    for %AmpSdk.Types.TextContent{text: t} <- content, do: IO.write(t)
  _ -> :ok
end)
```

## CLI Discovery

The SDK locates the Amp CLI by checking (in order):

1. `AMP_CLI_PATH` environment variable
2. `~/.amp/bin/amp`
3. `~/.local/bin/amp`
4. System `PATH`
5. Node.js `require.resolve('@sourcegraph/amp/package.json')`

Use `AmpSdk.CLI.resolve/0` to inspect the command spec:

```elixir
{:ok, spec} = AmpSdk.CLI.resolve()
IO.inspect(spec.program, label: "program")
IO.inspect(spec.argv_prefix, label: "argv prefix")
```

## Advanced CLI Settings via `settings_file`

The Amp CLI supports many settings beyond what the SDK exposes as `Options` fields. You can access all of them by pointing `Options.settings_file` to a JSON file:

```elixir
AmpSdk.run("task", %Options{settings_file: "/path/to/settings.json"})
```

When you also provide `Options.permissions` or `Options.skills`, the SDK merges those into your settings file automatically.

### Available Settings

These are the `amp.` prefix keys recognized by the CLI. All can be set in the settings JSON:

| Setting | Type | Description |
|---|---|---|
| `amp.proxy` | `string` | HTTP/HTTPS proxy URL for requests to Amp servers |
| `amp.network.timeout` | `integer` | Seconds to wait for network requests before timeout |
| `amp.tools.disable` | `[string]` | Tool names to disable (use `builtin:name` to target only builtins) |
| `amp.tools.enable` | `[string]` | Glob patterns of tools to enable (if set, only matching tools are active) |
| `amp.guardedFiles.allowlist` | `[string]` | File glob patterns allowed without confirmation (overrides built-in denylist) |
| `amp.mcpServers` | `object` | MCP server configurations (alternative to `Options.mcp_config`) |
| `amp.permissions` | `[object]` | Permission rules (alternative to `Options.permissions`) |
| `amp.dangerouslyAllowAll` | `boolean` | Skip all prompts (alternative to `Options.dangerously_allow_all`) |
| `amp.skills.path` | `string` | Path to custom skills (alternative to `Options.skills`) |
| `amp.toolbox.path` | `string` | Path to toolbox scripts (alternative to `Options.toolbox`) |
| `amp.notifications.enabled` | `boolean` | Enable sound notifications |
| `amp.notifications.system.enabled` | `boolean` | Enable system notifications when terminal unfocused |
| `amp.git.commit.coauthor.enabled` | `boolean` | Add Amp as co-author in git commits |
| `amp.git.commit.ampThread.enabled` | `boolean` | Add Amp-Thread trailer in git commits |
| `amp.showCosts` | `boolean` | Show cost tracking during thread execution |
| `amp.fuzzy.alwaysIncludePaths` | `[string]` | Globs always included in fuzzy file search (even if gitignored) |
| `amp.bitbucketToken` | `string` | Personal access token for Bitbucket Enterprise |
| `amp.experimental.modes` | `[string]` | Enable experimental agent modes by name |

### Example: Enterprise Configuration

```elixir
# Write a settings file for enterprise use
settings = %{
  "amp.proxy" => "http://proxy.corp.example.com:8080",
  "amp.network.timeout" => 60,
  "amp.tools.disable" => ["browser_navigate"],
  "amp.guardedFiles.allowlist" => ["config/**"],
  "amp.git.commit.coauthor.enabled" => true
}

path = Path.join(System.tmp_dir!(), "amp-settings.json")
File.write!(path, Jason.encode!(settings))

{:ok, result} = AmpSdk.run("Review the code", %Options{settings_file: path})
```
