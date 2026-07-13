# Migrating to Amp SDK 0.6

Amp SDK 0.6 retains the provider-facing API shape from 0.5 while moving its
shared command and session mechanics to `cli_subprocess_core` 0.2. The release
requires Elixir 1.19 or later.

## Dependency update

Update the SDK constraint:

```elixir
{:amp_sdk, "~> 0.6.0"}
```

Applications that also declare `cli_subprocess_core` directly must use the 0.2
line. Provider applications should not depend on raw Execution Plane modules;
use the shared core facades or Amp SDK values at their public boundaries.

## Public API compatibility

The 0.5 entry points for `AmpSdk.run/2`, `AmpSdk.execute/2`, command helpers,
thread and management functions, public option/message structs, and Amp-native
permissions and MCP helpers remain available. `governed_authority` is an
additive option for authority-materialized launches.

The intentional behavior changes are:

- runtime modules no longer read or inherit ambient provider `AMP_*`
  environment values;
- unknown permission actions and MCP server type/source discriminators are
  rejected instead of being accepted as valid known values;
- unknown MCP status and provider error codes project to bounded unknown values,
  with their original strings retained in diagnostic or `extra` data; and
- direct use of the former standalone transport package's types is no longer
  supported by this SDK. Shared process and transport values are accessed
  through `CliSubprocessCore` facades.

## Materialize environment explicitly

For standalone use, pass provider behavior environment through typed options:

```elixir
AmpSdk.run("Summarize this project", %AmpSdk.Types.Options{
  env: %{"AMP_API_KEY" => api_key}
})
```

If the host intentionally reads OS environment variables, do so in
`config/runtime.exs` or another configuration provider, then materialize the
result into application configuration or `Options.env`. Governed launches must
receive command, cwd, environment, credentials, target, command reference, and
redaction reference from the supplied authority; unmanaged native settings are
rejected.

## Release dependency order

The release consumes `cli_subprocess_core 0.2.0`, which in turn follows the
published foundation: Ground Plane leaves, Execution Plane 0.1.0, then CLI
Subprocess Core 0.2.0. A Hex-only install of Amp SDK 0.6 cannot succeed until
that lower release chain is published.
