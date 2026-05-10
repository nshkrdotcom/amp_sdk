# Repository Guidelines

## Project Structure
- `lib/` contains public `AmpSdk` modules and internal runtime adapters.
- `test/` contains ExUnit coverage; `test/support/` is test-only and may contain lower-runtime fixtures.
- `guides/`, `examples/`, `README.md`, and `CHANGELOG.md` must stay aligned with runtime and dependency behavior.
- `doc/` is generated output and should not be edited.

## Execution Plane Stack
- This SDK sits above `cli_subprocess_core`; do not expose raw `ExecutionPlane.*` internals in public APIs or docs.
- Use `CliSubprocessCore` facades for execution surfaces, transport errors, transport info, process exits, sessions, commands, and provider model policy.
- Dependency source selection is handled by `build_support/dependency_sources.exs` and `build_support/dependency_sources.config.exs`.
- Local dependency overrides use `.dependency_sources.local.exs`.
- Default dependency priority is `path -> GitHub -> Hex`; publish mode is Hex-only and must fail with exact blockers if an internal dep is unavailable on Hex.
- Dependency source selection must not use environment variables.
- Weld maintains helper drift, manifests, clone checks, publish checks, and publish order, but this repo is not a Weld consumer in this pass and must not receive a blind Weld dependency.
- Keep `cli_subprocess_core` dependency resolution publish-aware: local path deps for sibling development, Hex constraints for release builds.
- Runtime application code under `lib/**` must not call direct OS env APIs such as `System.get_env`, `System.fetch_env`, `System.put_env`, or `System.delete_env`.
- Runtime and deployment env reads belong in `config/runtime.exs` or an explicit `Config.Provider`.
- Library APIs receive explicit options, config structs, credential providers, application config materialized by the top-level app, or caller-supplied env maps.
- Tests may manipulate env only for config-boundary, SDK compatibility, or live-wrapper checks.

## ASM Boundary
- Amp-native controls such as thread operations, tasks, skills, permissions, MCP, review, usage, settings files, UI suppression flags, and mode selection belong in this SDK.
- Common mechanics should move down to `cli_subprocess_core` only when at least one other provider needs the same neutral mechanism.
- ASM may derive only common placement/session data unless a caller passes explicit Amp-native overrides through a provider extension or calls this SDK directly.
- Before asserting an Amp-native feature exists, add or update `guides/provider_behavior_manifest.md` with source, fixture, or live-smoke evidence.
- SDK-direct promotion examples in `examples/promotion_path/` must not import or alias ASM.

## Gates
- Run `mix format`.
- Run `mix compile --warnings-as-errors`.
- Run `mix test`.
- Run `mix credo --strict`.
- Run `mix dialyzer`.
- Run `mix docs --warnings-as-errors`.
