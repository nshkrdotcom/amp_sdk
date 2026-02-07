defmodule AmpSdkTest do
  use ExUnit.Case
  doctest AmpSdk

  test "greets the world" do
    assert AmpSdk.hello() == :world
  end
end
