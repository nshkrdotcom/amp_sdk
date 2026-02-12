defmodule AmpSdk do
  @moduledoc """
  Elixir SDK for the Amp CLI.

  Provides programmatic access to Amp's AI-powered coding agent via the CLI.
  """

  alias AmpSdk.Error
  alias AmpSdk.Types
  alias AmpSdk.Types.{ErrorResultMessage, Options, ResultMessage}

  # === Execute ===

  @spec execute(String.t() | [Types.UserInputMessage.t() | map()], Options.t()) ::
          Enumerable.t(Types.stream_message())
  def execute(input, %Options{} = options \\ %Options{}) do
    AmpSdk.Stream.execute(input, options)
  end

  @spec run(String.t(), Options.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def run(prompt, %Options{} = options \\ %Options{}) do
    prompt
    |> execute(options)
    |> Enum.reduce(nil, fn
      %ResultMessage{result: result}, _acc -> {:ok, result}
      %ErrorResultMessage{error: error}, _acc -> {:error, Error.new(:execution_failed, error)}
      _msg, acc -> acc
    end)
    |> case do
      nil -> {:error, Error.new(:no_result, "No result received from stream")}
      result -> result
    end
  end

  # === Helpers ===

  @spec create_user_message(String.t()) :: Types.UserInputMessage.t()
  defdelegate create_user_message(text), to: Types

  @spec create_permission(String.t(), String.t(), keyword()) :: Types.Permission.t()
  def create_permission(tool, action, opts \\ []) do
    Types.Permission.new!(tool, action, opts)
  end

  # === Threads ===

  defdelegate threads_new(opts \\ []), to: AmpSdk.Threads, as: :new
  @spec threads_list(keyword()) :: {:ok, [AmpSdk.Types.ThreadSummary.t()]} | {:error, Error.t()}
  defdelegate threads_list(opts \\ []), to: AmpSdk.Threads, as: :list
  defdelegate threads_search(query, opts \\ []), to: AmpSdk.Threads, as: :search
  defdelegate threads_markdown(thread_id), to: AmpSdk.Threads, as: :markdown
  defdelegate threads_share(thread_id, opts \\ []), to: AmpSdk.Threads, as: :share
  defdelegate threads_rename(thread_id, name), to: AmpSdk.Threads, as: :rename
  defdelegate threads_archive(thread_id), to: AmpSdk.Threads, as: :archive
  defdelegate threads_delete(thread_id), to: AmpSdk.Threads, as: :delete
  defdelegate threads_handoff(thread_id, opts \\ []), to: AmpSdk.Threads, as: :handoff
  defdelegate threads_replay(thread_id, opts \\ []), to: AmpSdk.Threads, as: :replay

  # === Tools ===

  defdelegate tools_list(), to: AmpSdk.Tools, as: :list
  defdelegate tools_show(tool_name), to: AmpSdk.Tools, as: :show
  defdelegate tools_use(tool_name, opts \\ []), to: AmpSdk.Tools, as: :use
  defdelegate tools_make(tool_name, opts \\ []), to: AmpSdk.Tools, as: :make

  # === Tasks ===

  defdelegate tasks_list(), to: AmpSdk.Tasks, as: :list
  defdelegate tasks_import(json_file, opts \\ []), to: AmpSdk.Tasks, as: :import_tasks

  # === Review ===

  defdelegate review(opts \\ []), to: AmpSdk.Review, as: :run

  # === Skills ===

  defdelegate skills_add(source), to: AmpSdk.Skills, as: :add
  defdelegate skills_list(), to: AmpSdk.Skills, as: :list
  defdelegate skills_remove(name), to: AmpSdk.Skills, as: :remove
  defdelegate skills_info(name), to: AmpSdk.Skills, as: :info

  # === Permissions ===

  @spec permissions_list(keyword()) ::
          {:ok, [AmpSdk.Types.PermissionRule.t()]} | {:error, Error.t()}
  defdelegate permissions_list(opts \\ []), to: AmpSdk.Permissions, as: :list
  defdelegate permissions_test(tool_name, opts \\ []), to: AmpSdk.Permissions, as: :test
  defdelegate permissions_add(tool, action, opts \\ []), to: AmpSdk.Permissions, as: :add

  # === MCP ===

  defdelegate mcp_add(name, command_or_url, opts \\ []), to: AmpSdk.MCP, as: :add
  @spec mcp_list(keyword()) :: {:ok, [AmpSdk.Types.MCPServer.t()]} | {:error, Error.t()}
  defdelegate mcp_list(opts \\ []), to: AmpSdk.MCP, as: :list
  defdelegate mcp_remove(name), to: AmpSdk.MCP, as: :remove
  defdelegate mcp_doctor(), to: AmpSdk.MCP, as: :doctor
  defdelegate mcp_approve(name), to: AmpSdk.MCP, as: :approve
  defdelegate mcp_oauth_login(server_name, opts \\ []), to: AmpSdk.MCP, as: :oauth_login
  defdelegate mcp_oauth_logout(server_name, opts \\ []), to: AmpSdk.MCP, as: :oauth_logout
  defdelegate mcp_oauth_status(server_name, opts \\ []), to: AmpSdk.MCP, as: :oauth_status

  # === Usage ===

  defdelegate usage(), to: AmpSdk.Usage, as: :info
end
