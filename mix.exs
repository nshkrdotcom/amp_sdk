defmodule AmpSdk.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/nshkrdotcom/amp_sdk"
  @homepage_url "https://hex.pm/packages/amp_sdk"
  @docs_url "https://hexdocs.pm/amp_sdk"
  @cli_subprocess_core_requirement "~> 0.1.0"
  @cli_subprocess_core_repo "nshkrdotcom/cli_subprocess_core"
  def project do
    [
      app: :amp_sdk,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      name: "AmpSdk",
      source_url: @source_url,
      homepage_url: @homepage_url,
      dialyzer: [
        plt_add_apps: [:ex_unit],
        plt_file: {:no_warn, "priv/plts/project.plt"}
      ]
    ]
  end

  def application do
    [
      mod: {AmpSdk.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      workspace_dep(
        :cli_subprocess_core,
        "../cli_subprocess_core",
        @cli_subprocess_core_requirement,
        github: @cli_subprocess_core_repo
      ),
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:supertester, "~> 0.5.1", only: :test}
    ]
  end

  defp description do
    "An Elixir SDK for the Amp CLI - programmatic access to Amp's AI coding agent."
  end

  defp docs do
    [
      main: "readme",
      name: "AmpSdk",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @homepage_url,
      assets: %{"assets" => "assets"},
      logo: "assets/amp_sdk.svg",
      extras: [
        {"README.md", title: "Overview", filename: "readme"},
        {"guides/getting-started.md", title: "Getting Started"},
        {"guides/configuration.md", title: "Configuration"},
        {"guides/streaming.md", title: "Streaming"},
        {"guides/permissions.md", title: "Permissions"},
        {"guides/threads.md", title: "Threads"},
        {"guides/error-handling.md", title: "Error Handling"},
        {"guides/testing.md", title: "Testing"},
        {"guides/tools-and-management.md", title: "Tools And Management"},
        {"examples/README.md", title: "Examples", filename: "examples"},
        {"CHANGELOG.md", title: "Changelog"},
        {"LICENSE", title: "License"}
      ],
      groups_for_extras: [
        "Project Overview": ["README.md"],
        Foundations: [
          "guides/getting-started.md",
          "guides/configuration.md",
          "guides/permissions.md"
        ],
        Runtime: [
          "guides/streaming.md",
          "guides/threads.md",
          "guides/tools-and-management.md"
        ],
        Quality: [
          "guides/error-handling.md",
          "guides/testing.md"
        ],
        Examples: ["examples/README.md"],
        Reference: ["CHANGELOG.md", "LICENSE"]
      ],
      groups_for_modules: [
        "Core API": [
          AmpSdk,
          AmpSdk.Stream,
          AmpSdk.Threads,
          AmpSdk.Tools,
          AmpSdk.Review,
          AmpSdk.Command
        ],
        Management: [
          AmpSdk.Tasks,
          AmpSdk.Skills,
          AmpSdk.Permissions,
          AmpSdk.MCP,
          AmpSdk.Usage
        ],
        Transport: [
          AmpSdk.Transport,
          AmpSdk.Transport.Erlexec
        ],
        Types: [
          AmpSdk.Types,
          AmpSdk.Types.Options,
          AmpSdk.Types.Permission,
          AmpSdk.Types.SystemMessage,
          AmpSdk.Types.AssistantMessage,
          AmpSdk.Types.AssistantPayload,
          AmpSdk.Types.UserMessage,
          AmpSdk.Types.UserPayload,
          AmpSdk.Types.ResultMessage,
          AmpSdk.Types.ErrorResultMessage,
          AmpSdk.Types.UserInputMessage,
          AmpSdk.Types.TextContent,
          AmpSdk.Types.ToolUseContent,
          AmpSdk.Types.ToolResultContent,
          AmpSdk.Types.ThinkingContent,
          AmpSdk.Types.Usage,
          AmpSdk.Types.MCPServerStatus,
          AmpSdk.Types.ThreadSummary,
          AmpSdk.Types.PermissionRule,
          AmpSdk.Types.MCPServer,
          AmpSdk.Types.MCPStdioServer,
          AmpSdk.Types.MCPHttpServer
        ],
        Infrastructure: [
          AmpSdk.CLI,
          AmpSdk.Runtime.CLI
        ]
      ],
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
    <script>
      let initialized = false;
      window.addEventListener("exdoc:loaded", () => {
        if (!initialized) {
          mermaid.initialize({
            startOnLoad: false,
            theme: document.body.className.includes("dark") ? "dark" : "default"
          });
          initialized = true;
        }
        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            graphEl.innerHTML = svg;
            bindFunctions?.(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp before_closing_head_tag(:epub), do: ""

  defp before_closing_body_tag(:html), do: ""
  defp before_closing_body_tag(:epub), do: ""

  defp package do
    [
      name: "amp_sdk",
      description: description(),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Hex" => @homepage_url,
        "HexDocs" => @docs_url,
        "Amp" => "https://ampcode.com",
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: ["nshkrdotcom"],
      files:
        ~w(lib guides assets examples/README.md mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  defp workspace_dep(app, path, requirement, opts) do
    {release_opts, dep_opts} = Keyword.split(opts, [:github, :git, :branch, :tag, :ref])
    expanded_path = Path.expand(path, __DIR__)

    cond do
      hex_packaging?() ->
        {app, requirement, dep_opts}

      File.dir?(expanded_path) ->
        {app, Keyword.put(dep_opts, :path, path)}

      true ->
        {app, Keyword.merge(dep_opts, release_opts)}
    end
  end

  defp hex_packaging? do
    Enum.any?(System.argv(), &String.starts_with?(&1, "hex."))
  end
end
