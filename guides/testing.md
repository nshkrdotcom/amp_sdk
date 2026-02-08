# Testing

Strategies for testing code that depends on the Amp SDK.

## Unit Tests (Mocked)

Since the SDK shells out to the Amp CLI, unit tests should not call the real CLI. Instead, test your code's handling of the SDK's return values.

### Testing with Known Responses

```elixir
defmodule MyApp.AmpClientTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Types.{ResultMessage, ErrorResultMessage}

  test "handles successful result" do
    result = %ResultMessage{
      result: "All tests pass",
      duration_ms: 2000,
      num_turns: 1,
      is_error: false
    }

    assert result.result =~ "tests pass"
  end

  test "handles error result" do
    error = %ErrorResultMessage{
      error: "Permission denied",
      duration_ms: 100,
      is_error: true,
      permission_denials: ["Bash"]
    }

    assert error.is_error
    assert "Bash" in error.permission_denials
  end
end
```

### Testing Message Parsing

```elixir
test "parses JSON line into typed struct" do
  json = Jason.encode!(%{
    type: "result",
    subtype: "success",
    session_id: "T-123",
    is_error: false,
    result: "done",
    duration_ms: 500,
    num_turns: 1
  })

  assert {:ok, %AmpSdk.Types.ResultMessage{result: "done"}} =
    AmpSdk.Types.parse_stream_message(json)
end
```

## Integration Tests (Live)

Tag live tests with `@tag :live` and exclude them by default:

```elixir
# test/test_helper.exs
ExUnit.start(exclude: [:live])
```

```elixir
defmodule MyApp.AmpLiveTest do
  use ExUnit.Case, async: false

  @moduletag :live

  @tag timeout: 60_000
  test "executes a real prompt" do
    assert {:ok, result} = AmpSdk.run(
      "Reply with only: hello",
      %AmpSdk.Types.Options{dangerously_allow_all: true}
    )
    assert result =~ ~r/hello/i
  end
end
```

Run live tests:

```bash
mix test --include live
```

## Testing Argument Building

The `AmpSdk.Stream.build_args/1` function is public for testing:

```elixir
test "builds correct CLI args" do
  args = AmpSdk.Stream.build_args(%AmpSdk.Types.Options{
    mode: "smart",
    visibility: "private",
    labels: ["ci"]
  })

  assert "--execute" in args
  assert "--stream-json" in args
  assert "--mode" in args
  assert "--label" in args
end
```

## SDK Test Suite

```bash
# Run unit tests (mocked, fast)
mix test

# Run all tests including live CLI tests
mix test --include live
```
