# Migrating to 0.8

Amp SDK 0.8 aligns its subprocess runtime with
`cli_subprocess_core ~> 0.7.0`. This makes the SDK compatible with
`agent_session_manager` 0.14 and newer releases on the same core line.

Update the dependency:

```elixir
{:amp_sdk, "~> 0.8.0"}
```

No Amp-facing API migration is required. Applications that declare
`cli_subprocess_core` directly must allow the `~> 0.7.0` line.
