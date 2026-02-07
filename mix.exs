defmodule AmpSdk.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/amp_sdk"

  def project do
    [
      app: :amp_sdk,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: "An Elixir SDK for the Amp CLI — programmatic access to Amp's AI coding agent",
      package: package(),
      name: "AmpSdk",
      source_url: @source_url,
      homepage_url: @source_url,
      dialyzer: [
        plt_add_apps: [:ex_unit],
        plt_file: {:no_warn, "priv/plts/project.plt"}
      ]
    ]
  end

  def application do
    [
      mod: {AmpSdk.Application, []},
      extra_applications: [:logger, :erlexec]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:erlexec, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:supertester, "~> 0.5.1", only: :test}
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "AmpSdk",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      assets: %{"assets" => "assets"},
      logo: "assets/amp_sdk.svg",
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/configuration.md",
        "guides/streaming.md",
        "guides/permissions.md",
        "guides/threads.md",
        "guides/error-handling.md",
        "guides/testing.md",
        "guides/tools-and-management.md",
        {"examples/README.md", filename: "examples"},
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        "Getting Started": [
          "README.md",
          "guides/getting-started.md"
        ],
        Guides: [
          "guides/configuration.md",
          "guides/streaming.md",
          "guides/permissions.md",
          "guides/threads.md",
          "guides/tools-and-management.md"
        ],
        "Testing & Errors": [
          "guides/error-handling.md",
          "guides/testing.md"
        ],
        Examples: [
          "examples/README.md"
        ],
        "Release Notes": [
          "CHANGELOG.md",
          "LICENSE"
        ]
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
          AmpSdk.Types.MCPStdioServer,
          AmpSdk.Types.MCPHttpServer
        ],
        Infrastructure: [
          AmpSdk.CLI,
          AmpSdk.Errors,
          AmpSdk.Errors.AmpError,
          AmpSdk.Errors.CLINotFoundError,
          AmpSdk.Errors.ProcessError,
          AmpSdk.Errors.JSONParseError
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
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/nshkrdotcom/amp_sdk",
        "Amp" => "https://ampcode.com"
      },
      maintainers: ["NSHkr"],
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end
end
