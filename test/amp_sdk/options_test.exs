defmodule AmpSdk.OptionsTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Types.Options
  alias CliSubprocessCore.ExecutionSurface
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

    test "normalizes a supplied execution_surface into the canonical core struct" do
      validated =
        Options.validate!(%Options{
          execution_surface: %ExecutionSurface{
            surface_kind: :static_ssh,
            transport_options: [destination: "amp.example", ssh_options: [BatchMode: "yes"]],
            target_id: "amp-target-1",
            observability: %{lane: :amp}
          }
        })

      assert %ExecutionSurface{} = validated.execution_surface
      assert validated.execution_surface.surface_kind == :static_ssh
      assert validated.execution_surface.transport_options[:destination] == "amp.example"
      assert validated.execution_surface.target_id == "amp-target-1"
      assert validated.execution_surface.observability == %{lane: :amp}
    end

    test "raises when execution_surface is not a core execution surface struct" do
      assert_raise ArgumentError,
                   ~r/execution_surface must be a %CliSubprocessCore.ExecutionSurface{}/,
                   fn ->
                     Options.validate!(%Options{execution_surface: %{surface_kind: :static_ssh}})
                   end
    end
  end
end
