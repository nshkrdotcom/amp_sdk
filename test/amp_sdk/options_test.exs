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
            surface_kind: :ssh_exec,
            transport_options: [destination: "amp.example", ssh_options: [BatchMode: "yes"]],
            target_id: "amp-target-1",
            observability: %{lane: :amp}
          }
        })

      assert %ExecutionSurface{} = validated.execution_surface
      assert validated.execution_surface.surface_kind == :ssh_exec
      assert validated.execution_surface.transport_options[:destination] == "amp.example"
      assert validated.execution_surface.target_id == "amp-target-1"
      assert validated.execution_surface.observability == %{lane: :amp}
    end

    test "normalizes execution_surface maps and keywords into the canonical core struct" do
      from_map =
        Options.validate!(%Options{
          execution_surface: %{
            "surface_kind" => :ssh_exec,
            "transport_options" => [destination: "amp-map.example"],
            "target_id" => "amp-map-target"
          }
        })

      from_keyword =
        Options.validate!(%Options{
          execution_surface: [
            surface_kind: :ssh_exec,
            transport_options: [destination: "amp-keyword.example"],
            target_id: "amp-keyword-target"
          ]
        })

      assert %ExecutionSurface{} = from_map.execution_surface
      assert from_map.execution_surface.transport_options[:destination] == "amp-map.example"
      assert from_map.execution_surface.target_id == "amp-map-target"

      assert %ExecutionSurface{} = from_keyword.execution_surface

      assert from_keyword.execution_surface.transport_options[:destination] ==
               "amp-keyword.example"

      assert from_keyword.execution_surface.target_id == "amp-keyword-target"
    end

    test "raises when execution_surface cannot be normalized" do
      assert_raise ArgumentError, ~r/execution_surface is invalid/, fn ->
        Options.validate!(%Options{execution_surface: 123})
      end
    end

    test "execution_surface_opts/1 accepts either an options struct or a surface struct" do
      surface =
        Options.validate!(%Options{
          execution_surface: [
            surface_kind: :ssh_exec,
            transport_options: [destination: "amp-opts.example"],
            target_id: "amp-opts-target"
          ]
        }).execution_surface

      assert Options.execution_surface_opts(surface)[:target_id] == "amp-opts-target"

      assert Options.execution_surface_opts(%Options{execution_surface: surface})[:target_id] ==
               "amp-opts-target"

      assert Options.execution_surface_opts(surface)[:transport_options][:destination] ==
               "amp-opts.example"

      assert Options.execution_surface_opts(nil) == []
    end
  end
end
