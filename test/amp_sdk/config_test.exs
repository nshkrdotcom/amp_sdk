defmodule AmpSdk.ConfigTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Config

  test "read_option/3 resolves atom keys" do
    assert Config.read_option(%{mode: "smart"}, :mode, "fallback") == "smart"
    assert Config.read_option(%{"mode" => "deep"}, :mode, "fallback") == "fallback"
    assert Config.read_option(%{}, :mode, "fallback") == "fallback"
  end

  test "read_option/3 prioritizes atom key when both atom and string keys are present" do
    assert Config.read_option(%{"mode" => "deep", mode: "smart"}, :mode, "fallback") == "smart"
  end

  test "fetch_option/3 reads atom key only" do
    assert {:ok, "smart"} = Config.fetch_option(%{mode: "smart"}, :mode)
    assert {:ok, "fallback"} = Config.fetch_option(%{"mode" => "deep"}, :mode, "fallback")
    assert {:ok, "smart"} = Config.fetch_option(%{"mode" => "deep", mode: "smart"}, :mode)
  end

  test "normalize_string_map/1 drops nil values" do
    assert Config.normalize_string_map(%{"A" => "1", :B => nil}) == %{"A" => "1"}
    assert Config.normalize_string_map([{"A", "1"}, {:B, nil}]) == %{"A" => "1"}
  end
end
