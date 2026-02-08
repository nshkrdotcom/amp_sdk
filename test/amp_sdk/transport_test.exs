defmodule AmpSdk.TransportTest do
  use ExUnit.Case, async: true

  alias AmpSdk.{Error, Transport}

  test "error_to_error/2 normalizes tagged transport errors to AmpSdk.Error" do
    error = Transport.error_to_error({:transport, :not_connected})

    assert %Error{} = error
    assert error.kind == :transport_error
    assert error.message == "Transport not connected"
  end

  test "error_to_error/2 accepts normalize overrides" do
    error = Transport.error_to_error({:transport, :timeout}, message: "custom")

    assert error.kind == :transport_error
    assert error.message == "custom"
  end
end
