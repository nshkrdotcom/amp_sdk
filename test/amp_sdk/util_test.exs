defmodule AmpSdk.UtilTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Util

  test "maybe_put_kw/3 only writes non-nil values" do
    assert [timeout: 10] = Util.maybe_put_kw([], :timeout, 10)
    assert [] = Util.maybe_put_kw([], :timeout, nil)
  end

  test "maybe_append/3 appends only truthy guards" do
    assert ["a", "b"] = Util.maybe_append(["a"], true, ["b"])
    assert ["a", "b"] = Util.maybe_append(["a"], "yes", ["b"])
    assert ["a"] = Util.maybe_append(["a"], false, ["b"])
    assert ["a"] = Util.maybe_append(["a"], nil, ["b"])
  end

  test "maybe_flag/3 appends a flag when enabled" do
    assert ["--no-ide"] = Util.maybe_flag([], true, "--no-ide")
    assert [] = Util.maybe_flag([], false, "--no-ide")
    assert [] = Util.maybe_flag([], nil, "--no-ide")
  end
end
