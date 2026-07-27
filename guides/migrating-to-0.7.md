# Migrating to 0.7

Amp SDK 0.7 aligns the direct SDK with `cli_subprocess_core 0.4.0`. Public
execution and management entry points remain compatible, but runtime limits,
capability requests, settings-file ownership, and terminal result fidelity are
now explicit.

## Dependency Update

```elixir
{:amp_sdk, "~> 0.7.0"}
```

Applications that declare the shared runtime directly must use:

```elixir
{:cli_subprocess_core, "~> 0.4.0"}
```

Publish and deploy Core 0.4 before resolving Amp SDK 0.7 from Hex.

## Timeout Semantics

`stream_timeout_ms` remains the idle interval between events. Add
`run_deadline_ms` when you need a total budget that chatty output cannot rearm:

```elixir
%AmpSdk.Types.Options{
  stream_timeout_ms: 30_000,
  run_deadline_ms: 180_000,
  transport_headless_timeout_ms: 5_000
}
```

The defaults are finite: 300 seconds for both idle and total stream limits, and
5 seconds for transport orphan reaping.

## Unsupported Common Capabilities

The common option names `completion_only` and `output_schema` now exist so
multi-provider callers can express intent consistently. Amp support has not
been proven. Requested values fail before CLI lookup with a typed
`:unsupported_capability` result whose details include the provider, feature,
option, and support state.

Do not treat native permission rules, `dangerously_allow_all`, or Amp modes as
completion-only equivalents. They do not prove that tools, prompts, MCP
servers, or writes are absent.

## Temporary Settings Files

Merged permission and skills settings now use Core's owner-tracked ephemeral
file primitive. The file is exclusive, stored directly in the operating-system
temporary directory, restricted to mode `0600`, and removed after normal
teardown or session-owner death. Code should not depend on the former
`temp_dir` runtime metadata or manually delete SDK-created settings files.

## Result Projection

`AmpSdk.Types.ResultMessage` retains its convenient `result`, timing, turn, and
usage fields and now also preserves:

- `provider_session_id`
- `status` and `stop_reason`
- the complete normalized `output`
- `object`, which remains `nil` without a verified structured-output contract
- `metadata` and the provider `raw` envelope
- `duration_api_ms`, `cost_usd`, and permission denials

Callers may keep matching `%ResultMessage{result: result}`. Consumers needing
audit or provider diagnostics should persist the added fields rather than
reconstructing them from text.

## Verification Boundary

No installed and authenticated Amp CLI was available in the 2026-07-27 release
environment. The release uses deterministic parser, subprocess-stub, lifecycle,
and package tests and makes no new authenticated live-provider claim.
