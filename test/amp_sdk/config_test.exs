defmodule AmpSdk.ConfigTest do
  use ExUnit.Case, async: true

  alias AmpSdk.{Config, Error}

  test "read_option/3 resolves atom and string keys" do
    assert Config.read_option(%{mode: "smart"}, :mode, "fallback") == "smart"
    assert Config.read_option(%{"mode" => "deep"}, :mode, "fallback") == "deep"
    assert Config.read_option(%{}, :mode, "fallback") == "fallback"
  end

  test "read_option/3 raises on conflicting atom/string keys" do
    assert_raise Error, ~r/conflicting values/, fn ->
      Config.read_option(%{"mode" => "deep", mode: "smart"}, :mode)
    end
  end

  test "fetch_option/3 returns typed error on conflicting atom/string keys" do
    assert {:error, %Error{kind: :invalid_configuration, message: message}} =
             Config.fetch_option(%{"mode" => "deep", mode: "smart"}, :mode)

    assert message =~ "conflicting values"
  end

  test "normalize_string_map/1 drops nil values" do
    assert Config.normalize_string_map(%{"A" => "1", :B => nil}) == %{"A" => "1"}
    assert Config.normalize_string_map([{"A", "1"}, {:B, nil}]) == %{"A" => "1"}
  end
end
