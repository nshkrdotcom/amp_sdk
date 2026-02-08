defmodule AmpSdk.ErrorNormalizeTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Error

  test "normalize/2 renders readable transport reasons" do
    error = Error.normalize({:transport, :not_connected}, kind: :transport_error)

    assert error.kind == :transport_error
    assert error.message == "Transport not connected"
  end

  test "normalize/2 renders readable task exit reasons" do
    error = Error.normalize({:task_exit, :boom}, kind: :task_exit)

    assert error.kind == :task_exit
    assert error.message == "Task exited: :boom"
  end
end
