defmodule AmpSdk.StreamTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Stream, as: AmpStream
  alias AmpSdk.Types.{Options, Permission}

  describe "build_args/1" do
    test "default options include --execute and --stream-json" do
      args = AmpStream.build_args(%Options{})
      assert "--execute" in args
      assert "--stream-json" in args
    end

    test "includes --mode" do
      args = AmpStream.build_args(%Options{mode: "deep"})
      idx = Enum.find_index(args, &(&1 == "--mode"))
      assert Enum.at(args, idx + 1) == "deep"
    end

    test "includes --visibility" do
      args = AmpStream.build_args(%Options{visibility: "private"})
      idx = Enum.find_index(args, &(&1 == "--visibility"))
      assert Enum.at(args, idx + 1) == "private"
    end

    test "includes --dangerously-allow-all" do
      args = AmpStream.build_args(%Options{dangerously_allow_all: true})
      assert "--dangerously-allow-all" in args
    end

    test "includes labels" do
      args = AmpStream.build_args(%Options{labels: ["test", "ci"]})

      label_indices =
        Enum.with_index(args)
        |> Enum.filter(fn {a, _} -> a == "--label" end)
        |> Enum.map(&elem(&1, 1))

      labels = Enum.map(label_indices, fn i -> Enum.at(args, i + 1) end)
      assert "test" in labels
      assert "ci" in labels
    end

    test "includes --mcp-config as JSON string" do
      config = %{"server" => %{"command" => "npx"}}
      args = AmpStream.build_args(%Options{mcp_config: config})
      idx = Enum.find_index(args, &(&1 == "--mcp-config"))
      config_str = Enum.at(args, idx + 1)
      assert {:ok, decoded} = Jason.decode(config_str)
      assert decoded["server"]["command"] == "npx"
    end

    test "handles continue_thread with thread ID" do
      args = AmpStream.build_args(%Options{continue_thread: "T-abc-123"})
      assert "threads" in args
      assert "continue" in args
      assert "T-abc-123" in args
    end

    test "uses --stream-json-thinking when thinking: true" do
      args = AmpStream.build_args(%Options{thinking: true})
      assert "--stream-json-thinking" in args
      refute "--stream-json" in args
    end

    test "uses --stream-json-input when input mode is json" do
      args = AmpStream.build_args(%Options{}, :json_input)
      assert "--stream-json-input" in args
      refute "--stream-json" in args
    end
  end

  describe "build_settings_file/1" do
    test "returns nil paths when permissions and skills are absent" do
      assert {:ok, nil, nil} =
               AmpStream.build_settings_file(%Options{permissions: nil, skills: nil})
    end

    test "merges base settings with permissions and skills" do
      base_dir = AmpSdk.TestSupport.tmp_dir!("amp_settings")
      settings_file = Path.join(base_dir, "settings.json")

      File.write!(settings_file, Jason.encode!(%{"existing" => true, "amp.skills.path" => "old"}))

      opts = %Options{
        settings_file: settings_file,
        skills: "/custom/skills",
        permissions: [Permission.new!("Bash", "ask")]
      }

      {:ok, merged_path, temp_dir} = AmpStream.build_settings_file(opts)

      try do
        assert File.exists?(merged_path)
        assert String.starts_with?(temp_dir, System.tmp_dir!())

        merged = merged_path |> File.read!() |> Jason.decode!()
        assert merged["existing"] == true
        assert merged["amp.skills.path"] == "/custom/skills"
        assert [%{"tool" => "Bash", "action" => "ask"}] = merged["amp.permissions"]
      after
        File.rm_rf(base_dir)
        File.rm_rf(temp_dir)
      end
    end

    test "cleans temp dir when settings serialization fails" do
      existing_temp_dirs =
        System.tmp_dir!()
        |> Path.join("amp-*")
        |> Path.wildcard()
        |> MapSet.new()

      assert {:error, %AmpSdk.Error{} = error} =
               AmpStream.build_settings_file(%Options{
                 permissions: [%{tool: "Bash", action: "ask", meta: self()}]
               })

      assert error.kind == :invalid_configuration

      new_temp_dirs =
        System.tmp_dir!()
        |> Path.join("amp-*")
        |> Path.wildcard()
        |> MapSet.new()

      leaked = MapSet.difference(new_temp_dirs, existing_temp_dirs)
      assert MapSet.size(leaked) == 0
    end
  end

  describe "build_env/1" do
    test "injects toolbox and SDK version" do
      env = AmpStream.build_env(%Options{env: %{"A" => "1"}, toolbox: "/toolbox"})

      assert env["A"] == "1"
      assert env["AMP_TOOLBOX"] == "/toolbox"
      assert env["AMP_SDK_VERSION"] == "elixir-" <> to_string(Application.spec(:amp_sdk, :vsn))
    end
  end
end
