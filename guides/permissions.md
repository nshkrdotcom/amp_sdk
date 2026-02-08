# Permissions

Permissions control which tools the Amp agent can use during execution. This is critical for safety — you can allow read-only operations while blocking file writes and shell commands.

## Creating Permissions

```elixir
perm = AmpSdk.create_permission("Bash", "allow")
perm = AmpSdk.create_permission("edit_file", "reject")
perm = AmpSdk.create_permission("Read", "ask", matches: %{"path" => "/secret/*"})
perm = AmpSdk.create_permission("Bash", "delegate", to: "bash -c")
```

## Actions

| Action | Description |
|---|---|
| `"allow"` | Permit the tool without prompting |
| `"reject"` | Block the tool entirely |
| `"ask"` | Prompt for approval (interactive mode only) |
| `"delegate"` | Route to another command (requires `to:`) |

## Match Conditions

Use `matches:` to apply permissions only when specific tool inputs match:

```elixir
AmpSdk.create_permission("Read", "allow", matches: %{"path" => "lib/**"})
AmpSdk.create_permission("Read", "reject", matches: %{"path" => "/etc/**"})
```

## Context

Restrict a permission to a specific execution context:

```elixir
AmpSdk.create_permission("Bash", "allow", context: "thread")
AmpSdk.create_permission("Bash", "reject", context: "subagent")
```

## Applying Permissions

Pass permissions via `Options.permissions`:

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

{:ok, review} = AmpSdk.run("Review the code in lib/", %Options{
  permissions: permissions,
  mode: "smart"
})
```

## How It Works

When permissions are provided, the SDK:

1. Creates a temporary `settings.json` file containing the permission rules
2. Passes `--settings-file <path>` to the CLI
3. Cleans up the temp file after execution completes

If you also provide a `settings_file` in Options, the SDK merges your permissions into that file's contents.

## Read-Only Mode Recipe

```elixir
read_only = [
  AmpSdk.create_permission("Read", "allow"),
  AmpSdk.create_permission("glob", "allow"),
  AmpSdk.create_permission("Grep", "allow"),
  AmpSdk.create_permission("Bash", "reject"),
  AmpSdk.create_permission("edit_file", "reject"),
  AmpSdk.create_permission("create_file", "reject")
]
```

## Allow-All Shortcut

For development/testing, skip all permission prompts:

```elixir
AmpSdk.run("Do anything", %Options{dangerously_allow_all: true})
```

> **Warning:** `dangerously_allow_all: true` lets the agent execute arbitrary shell commands, modify files, and more. Only use in trusted environments.
