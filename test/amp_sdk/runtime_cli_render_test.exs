defmodule AmpSdk.RuntimeCLIRenderTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Runtime.CLI
  alias AmpSdk.Types.{Options, Permission}

  test "renders Amp-native args and settings without resolving or spawning the CLI" do
    permission = Permission.new!("Bash", "reject")

    {:ok, render} =
      CLI.render_for_test(
        prompt: "hello",
        options: %Options{
          mode: "smart",
          visibility: "private",
          labels: ["sdk", "promotion"],
          mcp_config: %{"fs" => %{"command" => "npx"}},
          permissions: [permission],
          skills: "/tmp/skills",
          no_ide: true,
          no_notifications: true
        },
        execution_surface: [
          surface_kind: :local_subprocess,
          observability: %{suite: :promotion_path}
        ]
      )

    assert render.provider == :amp
    assert render.execution_surface.observability == %{suite: :promotion_path}
    assert render.provider_native.permissions == [permission]
    assert render.provider_native.skills == "/tmp/skills"
    assert render.settings_payload["amp.permissions"] == [%{action: "reject", tool: "Bash"}]

    assert render.settings_payload["amp.skills.path"] == "/tmp/skills"

    args = render.args
    assert Enum.take(args, 2) == ["--execute", "hello"]
    assert "--stream-json" in args
    assert flag_value(args, "--mode") == "smart"
    assert flag_value(args, "--visibility") == "private"
    assert repeated_values(args, "--label") == ["sdk", "promotion"]
    assert flag_value(args, "--mcp-config") == Jason.encode!(%{"fs" => %{"command" => "npx"}})
    assert "--no-ide" in args
    assert "--no-notifications" in args
  end

  defp flag_value(args, flag) do
    case Enum.find_index(args, &(&1 == flag)) do
      nil -> nil
      idx -> Enum.at(args, idx + 1)
    end
  end

  defp repeated_values(args, flag) do
    args
    |> Enum.with_index()
    |> Enum.filter(fn {value, _index} -> value == flag end)
    |> Enum.map(fn {_value, index} -> Enum.at(args, index + 1) end)
  end
end
