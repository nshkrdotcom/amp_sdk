defmodule AmpSdk.StringScanTest do
  use ExUnit.Case, async: true

  alias AmpSdk.StringScan

  describe "ascii_env_key?/1" do
    test "accepts shell-compatible env keys" do
      assert StringScan.ascii_env_key?("AMP_TEST_ALPHA")
      assert StringScan.ascii_env_key?("_AMP_TEST_ALPHA_1")
    end

    test "rejects invalid or non-binary env keys" do
      refute StringScan.ascii_env_key?("1AMP_TEST_ALPHA")
      refute StringScan.ascii_env_key?("AMP.TEST_ALPHA")
      refute StringScan.ascii_env_key?("AMP-TEST-ALPHA")
      refute StringScan.ascii_env_key?("")
      refute StringScan.ascii_env_key?(:amp_test_alpha)
    end
  end

  describe "split_on_repeated_spaces/1" do
    test "splits table columns only on repeated spaces" do
      assert StringScan.split_on_repeated_spaces(
               "OTP refactor tracking  2m ago  Workspace  4  T-0123"
             ) == ["OTP refactor tracking", "2m ago", "Workspace", "4", "T-0123"]
    end
  end

  describe "non_alphanumeric_separator?/1" do
    test "detects table separator rows" do
      assert StringScan.non_alphanumeric_separator?("-----  ----")
      assert StringScan.non_alphanumeric_separator?("─────  ────")
      refute StringScan.non_alphanumeric_separator?("Title  Last Updated")
    end
  end
end
