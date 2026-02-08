defmodule AmpSdk.DefaultsTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Defaults
  alias AmpSdk.Types.Options

  test "exposes centralized timeout defaults" do
    assert Defaults.command_timeout_ms() == 60_000
    assert Defaults.review_timeout_ms() == 300_000
    assert Defaults.stream_timeout_ms() == 300_000
    assert Defaults.transport_call_timeout_ms() == 5_000
    assert Defaults.transport_force_close_timeout_ms() == 500
    assert Defaults.transport_headless_timeout_ms() == 5_000
  end

  test "Options stream timeout tracks shared defaults" do
    assert %Options{}.stream_timeout_ms == Defaults.stream_timeout_ms()
  end
end
