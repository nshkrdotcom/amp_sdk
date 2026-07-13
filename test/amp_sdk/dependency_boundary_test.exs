defmodule AmpSdk.DependencyBoundaryTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @forbidden_deps [
    :agent_session_manager,
    :gemini_cli_sdk,
    :claude_agent_sdk,
    :codex_sdk,
    :inference
  ]

  test "amp_sdk does not declare ASM or sibling SDK deps" do
    assert_forbidden_deps_absent(Mix.Project.config()[:deps], @forbidden_deps)
  end

  test "release metadata targets Amp SDK 0.6.0 on Elixir 1.19" do
    assert Mix.Project.config()[:version] == "0.6.0"
    assert Mix.Project.config()[:elixir] == "~> 1.19"
  end

  test "publish mode selects cli_subprocess_core 0.2 from Hex" do
    assert "~> 0.2.0" ==
             @repo_root
             |> DependencySources.deps(publish?: true)
             |> Keyword.fetch!(:cli_subprocess_core)
  end

  test "public implementation does not expose raw Execution Plane modules" do
    for path <- Path.wildcard(Path.join(@repo_root, "lib/**/*.ex")) do
      refute File.read!(path) =~ "ExecutionPlane.",
             "raw Execution Plane reference in #{Path.relative_to(path, @repo_root)}"
    end
  end

  defp assert_forbidden_deps_absent(deps, forbidden_deps) when is_list(deps) do
    declared = MapSet.new(Enum.map(deps, &dep_name/1))

    Enum.each(forbidden_deps, fn dep ->
      refute MapSet.member?(declared, dep),
             "amp_sdk must not declare dependency on #{inspect(dep)}"
    end)
  end

  defp dep_name({name, _requirement}), do: name
  defp dep_name({name, _requirement, _opts}), do: name
end
