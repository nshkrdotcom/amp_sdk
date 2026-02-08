# Error Handling

The SDK returns tuples for execution outcomes and uses a single structured error envelope: `%AmpSdk.Error{}`.

## `run/2` Return Values

`AmpSdk.run/2` returns `{:ok, result}` or `{:error, %AmpSdk.Error{}}`:

```elixir
case AmpSdk.run("do something") do
  {:ok, result} ->
    IO.puts(result)

  {:error, %AmpSdk.Error{kind: :no_result}} ->
    IO.puts("No result received")

  {:error, %AmpSdk.Error{kind: kind, message: message}} ->
    IO.puts("#{kind}: #{message}")
end
```

Common `kind` values include `:cli_not_found`, `:command_timeout`, `:task_timeout`, `:command_failed`, `:execution_failed`, and `:invalid_configuration`.

## Exception Types

These can still be raised in explicit bang APIs or direct constructor usage:

- `AmpSdk.Error` (primary exception envelope)
- `AmpSdk.Errors.CLINotFoundError` (legacy)
- `AmpSdk.Errors.ProcessError` (legacy)
- `AmpSdk.Errors.JSONParseError` (legacy)
- `AmpSdk.Errors.AmpError`

Use tuple returns where possible and pattern-match on `%AmpSdk.Error{}` in application code.

## Low-Level Transport Errors

At the low-level transport boundary (`AmpSdk.Transport.Erlexec`), errors are returned as tagged tuples:

```elixir
{:error, {:transport, reason}}
```

This applies consistently across transport operations, including startup (`start/1`, `start_link/1`).

Normalize these when you need the unified envelope:

```elixir
error = AmpSdk.Transport.error_to_error({:transport, :timeout})
# or:
error = AmpSdk.Error.normalize({:transport, :timeout}, kind: :transport_error)
```

## Streaming Errors

When using `AmpSdk.execute/2`, errors are delivered inline as `ErrorResultMessage` structs rather than raising exceptions:

```elixir
AmpSdk.execute("prompt")
|> Enum.each(fn
  %AmpSdk.Types.ErrorResultMessage{error: error, permission_denials: denials} ->
    IO.puts("Error: #{error}")
    if denials, do: IO.puts("Denied tools: #{inspect(denials)}")

  %AmpSdk.Types.ResultMessage{result: result} ->
    IO.puts("Success: #{result}")

  _ -> :ok
end)
```

## Timeout Handling

Use `Options.stream_timeout_ms` for stream receive timeout control:

```elixir
alias AmpSdk.Types.Options

AmpSdk.execute("slow task", %Options{stream_timeout_ms: 30_000})
|> Enum.to_list()
```

You can still wrap long-running calls in a `Task` if you need outer cancellation:

```elixir
task = Task.async(fn -> AmpSdk.run("slow task") end)

case Task.yield(task, 30_000) || Task.shutdown(task) do
  {:ok, {:ok, result}} -> IO.puts(result)
  {:ok, {:error, %AmpSdk.Error{message: msg}}} -> IO.puts("Error: #{msg}")
  nil -> IO.puts("Timed out after 30s")
end
```
