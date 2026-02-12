# Tools & Management

The SDK wraps all Amp CLI management subcommands for programmatic access.

## Tools

List, inspect, and invoke tools directly:

```elixir
# List all available tools
{:ok, output} = AmpSdk.tools_list()

# Show a tool's schema and description
{:ok, schema} = AmpSdk.tools_show("Read")

# Invoke a tool directly (bypasses the agent loop)
{:ok, result} = AmpSdk.tools_use("Read",
  only: "content",
  args: [path: "/tmp/file.txt", read_range: [1, 20]]
)

# Create a toolbox skeleton (interactive; may fail in headless CI)
{:ok, _} = AmpSdk.tools_make("my_tool")
```

## Tasks

Import and list tasks:

```elixir
{:ok, _} = AmpSdk.tasks_import("tasks.json", dry_run: true)
{:ok, output} = AmpSdk.tasks_list()
```

## Code Review

Run automated code reviews.

`amp review` currently requires `--dangerously-allow-all`, so pass
`dangerously_allow_all: true`:

```elixir
# Review uncommitted changes
{:ok, review} = AmpSdk.review(dangerously_allow_all: true)

# Review a commit range
{:ok, review} = AmpSdk.review(diff: "main...HEAD", dangerously_allow_all: true)

# Focus on specific files with instructions
{:ok, review} = AmpSdk.review(
  diff: "HEAD~3",
  files: ["lib/auth.ex"],
  instructions: "Focus on security issues",
  dangerously_allow_all: true
)

# Summary only (no full review)
{:ok, summary} = AmpSdk.review(diff: "HEAD~1", summary_only: true, dangerously_allow_all: true)
```

## Skills

Manage custom skills:

```elixir
# List installed skills
{:ok, output} = AmpSdk.skills_list()

# Install from GitHub
{:ok, _} = AmpSdk.skills_add("github.com/user/my-skill")

# Get skill info
{:ok, info} = AmpSdk.skills_info("my-skill")

# Remove a skill
{:ok, _} = AmpSdk.skills_remove("my-skill")
```

## Permissions

Manage and test permission rules:

```elixir
# List current rules
{:ok, rules} = AmpSdk.permissions_list()
Enum.each(rules, fn rule -> IO.puts("#{rule.action} #{rule.tool}") end)

# Test if a tool would be allowed
{:ok, result} = AmpSdk.permissions_test("Bash")

# Add a rule
{:ok, _} = AmpSdk.permissions_add("Bash", "allow")
```

See the [Permissions guide](permissions.md) for creating inline permission rules via `Options.permissions`.

## MCP Servers

Manage Model Context Protocol servers:

```elixir
# List configured servers
{:ok, servers} = AmpSdk.mcp_list()
Enum.each(servers, fn server -> IO.puts("#{server.name} [#{server.type}]") end)

# Add a local command server in workspace settings
{:ok, _} = AmpSdk.mcp_add("filesystem", ["npx", "-y", "@modelcontextprotocol/server-filesystem"],
  workspace: true
)

# Add a remote URL server
{:ok, _} = AmpSdk.mcp_add("hugging-face", "https://huggingface.co/mcp")

# Add with environment variables
{:ok, _} = AmpSdk.mcp_add("postgres", ["npx", "-y", "@modelcontextprotocol/server-postgres"],
  env: [{"PGUSER", "myuser"}]
)

# Check server health
{:ok, output} = AmpSdk.mcp_doctor()

# Approve a workspace server (global servers cannot be approved)
{:ok, _} = AmpSdk.mcp_approve("filesystem")

# Remove a server
{:ok, _} = AmpSdk.mcp_remove("filesystem")
```

### MCP OAuth

Manage OAuth credentials for HTTP MCP servers.

The server must already be configured (via `mcp_add/3`) and expose OAuth metadata:

```elixir
# Register OAuth credentials
{:ok, _} = AmpSdk.mcp_oauth_login("my-server",
  server_url: "https://my-server.example.com/mcp",
  client_id: "my-client-id",
  client_secret: "my-secret"
)

# Check OAuth status
{:ok, status} = AmpSdk.mcp_oauth_status("my-server", timeout: 15_000)

# Remove OAuth credentials
{:ok, _} = AmpSdk.mcp_oauth_logout("my-server", timeout: 15_000)
```

## Usage

Check credit balance and usage:

```elixir
{:ok, output} = AmpSdk.usage()
IO.puts(output)
# => Signed in as user@example.com
# => Individual credits: $99.47 remaining
```
