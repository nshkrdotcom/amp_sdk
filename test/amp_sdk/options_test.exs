defmodule AmpSdk.OptionsTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Types.Options
  alias CliSubprocessCore.ModelRegistry
  alias CliSubprocessCore.ModelRegistry.Selection

  describe "Options.validate!/1" do
    test "normalizes a supplied model_payload into the canonical selection struct" do
      {:ok, payload} = ModelRegistry.build_arg_payload(:amp, nil, [])

      validated =
        Options.validate!(%Options{
          model_payload: Map.from_struct(payload)
        })

      assert %Selection{} = validated.model_payload
      assert validated.model_payload == payload
    end

    test "raises when model_payload is invalid for :amp" do
      assert_raise ArgumentError, ~r/model resolution failed for :amp/, fn ->
        Options.validate!(%Options{
          model_payload: %{provider: :codex, resolved_model: "gpt-5.4"}
        })
      end
    end

    test "raises when stream_timeout_ms is not positive" do
      assert_raise ArgumentError, ~r/stream_timeout_ms must be a positive integer/, fn ->
        Options.validate!(%Options{stream_timeout_ms: 0})
      end
    end
  end
end
