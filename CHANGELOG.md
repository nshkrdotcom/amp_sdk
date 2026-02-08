# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-02-07

### Added

- Typed management models for list-style APIs:
  - `AmpSdk.Types.ThreadSummary`
  - `AmpSdk.Types.PermissionRule`
  - `AmpSdk.Types.MCPServer`
- Raw output accessors for callers that still need plain CLI output:
  - `AmpSdk.threads_list_raw/1`
  - `AmpSdk.permissions_list_raw/1`
  - `AmpSdk.mcp_list_raw/1`

### Changed

- `threads_list/1` now returns `{:ok, [%AmpSdk.Types.ThreadSummary{}]}` instead of raw table text.
- `permissions_list/1` now requests CLI JSON and returns typed `%AmpSdk.Types.PermissionRule{}` entries.
- `mcp_list/1` now requests CLI JSON and returns typed `%AmpSdk.Types.MCPServer{}` entries.
- `threads_list/1`, `permissions_list/1`, and `mcp_list/1` now accept keyword opts, with zero-arity wrappers preserved via defaults.
- Documentation, guides, and examples now use typed list APIs as the primary path.

### Fixed

- Downstream consumers no longer need to call list functions and then parse/`length` raw CLI table strings for management data.

## [0.1.0] - 2025-02-07

### Added

- Initial public release of `amp_sdk` for Elixir with full Amp CLI coverage.
- Public facade (`AmpSdk`) exposing 37 API functions across:
  - Execution: `execute/2`, `run/2`, `create_user_message/1`, `create_permission/3`
  - Threads: `threads_new/1`, `threads_list/0`, `threads_search/2`, `threads_markdown/1`, `threads_share/2`, `threads_rename/2`, `threads_archive/1`, `threads_delete/1`, `threads_handoff/1`, `threads_replay/1`
  - Tools: `tools_list/0`, `tools_show/1`, `tools_use/2`, `tools_make/1`
  - Tasks: `tasks_list/0`, `tasks_import/1`
  - Review: `review/1`
  - Skills: `skills_add/1`, `skills_list/0`, `skills_remove/1`, `skills_info/1`
  - Permissions: `permissions_list/0`, `permissions_test/2`, `permissions_add/3`
  - MCP: `mcp_add/3`, `mcp_list/0`, `mcp_remove/1`, `mcp_doctor/0`, `mcp_approve/1`, `mcp_oauth_login/2`, `mcp_oauth_logout/1`, `mcp_oauth_status/1`
  - Usage: `usage/0`
- Streaming engine (`AmpSdk.Stream`) built on `Stream.resource/3` with typed message parsing.
- Transport layer (`AmpSdk.Transport` + `AmpSdk.Transport.Erlexec`) for subprocess lifecycle, I/O, and cleanup.
- Command stack with CLI discovery plus internal synchronous command execution and shared wrapper routing.
- Complete types system (`AmpSdk.Types`) including stream messages, content blocks, permission/MCP structs, and options.
- Unified error envelope (`AmpSdk.Error`) with legacy exception modules kept in `AmpSdk.Errors`.
- Settings file merge support for inline permissions and custom skills paths.
- Documentation set:
  - Root README
  - 8 guides in `guides/`
  - 28 runnable examples in `examples/` plus `examples/run_all.sh`
- Test coverage:
  - 177 tests total (including live tests tagged `:live`, excluded by default)

### Changed

- Internal process `:DOWN` waiting logic is now shared through a common helper module to reduce duplicated monitor wait code across async/command/stream paths.

### Fixed

- Stream cleanup now drains pending `{:amp_sdk_transport, ref, event}` messages for the finished stream reference, preventing mailbox residue in long-lived caller processes.
- Command collection now flushes trailing erlexec `stdout`/`stderr`/`DOWN` messages on the normal `:DOWN` completion path (not only timeout/stop paths).
- `AmpSdk.Transport.Erlexec` safe-call path now runs through supervised tasks (`AmpSdk.TaskSupervisor`) instead of unsupervised per-call `spawn_monitor` helpers.
- CLI Node.js package resolution fallback (`require.resolve`) is now bounded by a probe timeout (`2_000ms`) to avoid indefinite `CLI.resolve/0` hangs.
- `AmpSdk.Transport.Erlexec` startup (`start` / `start_link`) now returns consistent tagged transport errors (`{:error, {:transport, reason}}`) on startup/init failures.
- Config/env normalization now drops `nil` entries for string maps, CLI env overrides, and MCP `env`/`headers` constructors instead of coercing them into empty-string values.
- `permissions add` argument order corrected to CLI format: `<action> <tool>`.
- `permissions_add/3` wrapper support added for `--to` and `--workspace`.
- `tools_use/2` no longer forces `stdin: nil` (prevents headless hangs/timeouts when no input is provided).
- `review/1` updated to support global `--dangerously-allow-all` placement before `review`.
- Delegate/signature and wrapper behavior alignment for `threads_share/2` and management command argument construction.
- Internal task spawning now relies on OTP-supervised `AmpSdk.TaskSupervisor` startup (`Application.ensure_all_started/1`) instead of ad-hoc fallback supervisor singletons.
- Internal command timeout/send-failure cleanup now uses stop-then-kill escalation with explicit DOWN confirmation to avoid orphaned subprocesses and mailbox noise.
- Transport shutdown escalation now reports force-close call-timeout errors instead of internally killing the GenServer process.
- Stream cleanup escalation now uses `:shutdown` before `:kill` for transport teardown.
- Async timeout/task-exit paths now return `%AmpSdk.Error{}` (`:task_timeout`, `:task_exit`) consistently.
- Shared defaults/messages and a shared wrapper invocation helper were added to remove duplicated timeout constants and CLI invocation glue.
- Warning cleanup and docs/examples synchronization with current CLI behavior.
- Transport `safe_call/3` now isolates `GenServer.call/3` in a monitored helper process so timeout/error handling is contained and deterministic.
- Headless `AmpSdk.Transport.Erlexec` instances now support idle auto-shutdown (`:headless_timeout_ms`, default `5_000`) to avoid orphaned subprocesses when no subscriber is attached.
- Exit finalization now drains stdout in bounded batches instead of unbounded single-callback loops.
- Config option reading now uses `fetch_option/3` conflict detection and raises `%AmpSdk.Error{kind: :invalid_configuration}` on atom/string key conflicts.
- Low-level transport errors can now be normalized with `AmpSdk.Transport.error_to_error/2`.
- Timeout defaults are now centralized in the internal defaults module and reused by review/stream/transport paths.
