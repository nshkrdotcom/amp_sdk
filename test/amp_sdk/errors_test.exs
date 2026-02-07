defmodule AmpSdk.ErrorsTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Errors.{AmpError, CLINotFoundError, JSONParseError, ProcessError}

  describe "AmpError" do
    test "exception/1 with message string" do
      error = AmpError.exception("something broke")
      assert error.message == "something broke"
      assert error.exit_code == 1
      assert error.details == ""
    end

    test "exception/1 with keyword list" do
      error = AmpError.exception(message: "custom", exit_code: 42, details: "more info")
      assert error.message == "custom"
      assert error.exit_code == 42
      assert error.details == "more info"
    end

    test "implements Exception" do
      error = AmpError.exception("test")
      assert Exception.message(error) == "test"
    end
  end

  describe "CLINotFoundError" do
    test "default message" do
      error = CLINotFoundError.exception([])
      assert error.message == "Amp CLI not found"
      assert error.exit_code == 127
      assert error.details =~ "install"
    end

    test "custom message" do
      error = CLINotFoundError.exception("custom not found")
      assert error.message == "custom not found"
      assert error.exit_code == 127
    end
  end

  describe "ProcessError" do
    test "stores exit code and stderr" do
      error =
        ProcessError.exception(message: "failed", exit_code: 2, stderr: "err", signal: "SIGTERM")

      assert error.message == "failed"
      assert error.exit_code == 2
      assert error.stderr == "err"
      assert error.signal == "SIGTERM"
    end

    test "defaults" do
      error = ProcessError.exception(message: "failed")
      assert error.exit_code == 1
      assert error.stderr == ""
      assert error.signal == ""
    end
  end

  describe "JSONParseError" do
    test "stores raw line" do
      error = JSONParseError.exception(message: "bad json", raw_line: "{broken")
      assert error.message == "bad json"
      assert error.raw_line == "{broken"
    end
  end
end
