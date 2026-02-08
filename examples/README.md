# Examples

Runnable examples demonstrating every public function of the Amp SDK for Elixir.

> **Prerequisite:** The [Amp CLI](https://ampcode.com) must be installed and authenticated (`amp login`).

> **Behavior note:** Some examples are optional and return exit code `20` (skip) when prerequisites are missing. `run_all.sh` reports these as skipped instead of passed/failed.
> - `tools_make.exs`: skips automatically if the installed Amp CLI requires interactive input
> - `threads_handoff_replay.exs`: set `AMP_RUN_REPLAY=1` to run replay
> - `mcp_oauth.exs`: set `AMP_MCP_OAUTH_SERVER` and `AMP_MCP_OAUTH_SERVER_URL` to run status/logout; set `AMP_MCP_OAUTH_RUN_LOGIN=1` to run login too

## Run All

```bash
./examples/run_all.sh
```

Or run individually:

```bash
mix run examples/<name>.exs
```

## Execute

| Example | Description |
|---|---|
| [basic_execute.exs](basic_execute.exs) | Stream all message types with pattern matching |
| [run_simple.exs](run_simple.exs) | Blocking `run/2` returning final result |
| [create_user_message.exs](create_user_message.exs) | Multi-turn via `create_user_message/1` |
| [thinking.exs](thinking.exs) | Thinking blocks via `--stream-json-thinking` |
| [no_ide_mode.exs](no_ide_mode.exs) | Headless flags: `--no-ide`, `--no-notifications`, `--no-color` |
| [continue_thread.exs](continue_thread.exs) | Multi-turn conversation with thread continuation |
| [with_permissions.exs](with_permissions.exs) | Fine-grained tool permissions via `create_permission/3` |

## Management

| Example | Description |
|---|---|
| [usage.exs](usage.exs) | Credit balance and usage info |
| [tools_list.exs](tools_list.exs) | List all available tools |
| [tools_show.exs](tools_show.exs) | Show tool schema (e.g., `Read`) |
| [tools_use.exs](tools_use.exs) | Invoke a tool directly |
| [tools_make.exs](tools_make.exs) | Create a new tool (auto-skips if CLI requires interactive input) |
| [skills_list.exs](skills_list.exs) | List installed skills |
| [skills_manage.exs](skills_manage.exs) | Skill lifecycle: add, info, remove |
| [permissions_list.exs](permissions_list.exs) | List permission rules |
| [permissions_manage.exs](permissions_manage.exs) | Test and add permissions |
| [tasks_list.exs](tasks_list.exs) | List tasks |
| [tasks_import.exs](tasks_import.exs) | Import tasks from JSON |
| [review.exs](review.exs) | Code review with summary |

## Threads

| Example | Description |
|---|---|
| [threads.exs](threads.exs) | Create thread + export as Markdown |
| [thread_lifecycle.exs](thread_lifecycle.exs) | Full lifecycle: create, rename, share, archive, delete |
| [threads_list.exs](threads_list.exs) | List all threads |
| [threads_search.exs](threads_search.exs) | Search threads by query |
| [threads_handoff_replay.exs](threads_handoff_replay.exs) | Thread handoff and replay |

## MCP

| Example | Description |
|---|---|
| [mcp_list.exs](mcp_list.exs) | List configured MCP servers |
| [mcp_doctor.exs](mcp_doctor.exs) | Check MCP server health |
| [mcp_manage.exs](mcp_manage.exs) | MCP lifecycle: add, approve, remove |
| [mcp_oauth.exs](mcp_oauth.exs) | OAuth: status, login, logout |

## Adding New Examples

1. Create a `.exs` file in this directory
2. End with `System.halt(0)` to prevent the BEAM from hanging
3. Add a `run_example` call in `run_all.sh`
4. Use `%Options{dangerously_allow_all: true}` for non-interactive execution
