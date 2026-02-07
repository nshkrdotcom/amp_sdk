defmodule AmpSdk.StderrBugTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Types.Options

  describe "mode validation" do
    test "build_args includes --mode" do
      args = AmpSdk.Stream.build_args(%Options{mode: "rush"})
      idx = Enum.find_index(args, &(&1 == "--mode"))
      assert Enum.at(args, idx + 1) == "rush"
    end

    test "build_args with deep mode" do
      args = AmpSdk.Stream.build_args(%Options{mode: "deep"})
      idx = Enum.find_index(args, &(&1 == "--mode"))
      assert Enum.at(args, idx + 1) == "deep"
    end
  end
end
