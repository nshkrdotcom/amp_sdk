defmodule AmpSdk.Types.ThreadSummary do
  @moduledoc """
  Structured representation of a thread entry returned by `AmpSdk.threads_list/1`.
  """

  @enforce_keys [:id, :title, :last_updated, :visibility, :messages]
  defstruct [:id, :title, :last_updated, :visibility, :messages]

  @type visibility :: :private | :public | :workspace | :group | :unknown

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          last_updated: String.t(),
          visibility: visibility(),
          messages: non_neg_integer()
        }
end

defmodule AmpSdk.Types.PermissionRule do
  @moduledoc """
  Structured representation of a permission rule returned by `AmpSdk.permissions_list/1`.
  """

  alias AmpSdk.{Error, Schema}
  alias CliSubprocessCore.Schema.Conventions

  @enforce_keys [:tool, :action]
  @allowed_actions ~w(allow reject ask delegate)
  @known_fields ["tool", "action", "context", "to", "matches"]
  @schema Zoi.map(
            %{
              "tool" => Conventions.trimmed_string() |> Zoi.min(1),
              "action" => Conventions.trimmed_string() |> Zoi.min(1),
              "context" => Conventions.optional_trimmed_string(),
              "to" => Conventions.optional_trimmed_string(),
              "matches" => Conventions.optional_map()
            },
            unrecognized_keys: :preserve
          )

  defstruct [:tool, :action, :context, :to, :matches, extra: %{}]

  @type t :: %__MODULE__{
          tool: String.t(),
          action: String.t(),
          context: String.t() | nil,
          to: String.t() | nil,
          matches: map() | nil,
          extra: map()
        }

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec parse(map() | t()) ::
          {:ok, t()}
          | {:error, {:invalid_permission_rule, CliSubprocessCore.Schema.error_detail()}}
  def parse(%__MODULE__{} = rule), do: {:ok, rule}

  def parse(map) when is_map(map) do
    case Schema.parse(@schema, map, :invalid_permission_rule) do
      {:ok, parsed} ->
        {known, extra} = Schema.split_extra(parsed, @known_fields)

        build_rule(known, extra)

      {:error, {:invalid_permission_rule, details}} ->
        {:error, {:invalid_permission_rule, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = rule), do: rule

  def parse!(map) when is_map(map) do
    case parse(map) do
      {:ok, rule} ->
        rule

      {:error, {:invalid_permission_rule, details}} ->
        raise Error.new(:invalid_configuration, "Invalid permission rule", cause: details)
    end
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = rule) do
    %{
      "tool" => rule.tool,
      "action" => rule.action,
      "context" => rule.context,
      "to" => rule.to,
      "matches" => rule.matches
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(rule.extra)
  end

  defp build_rule(known, extra) do
    action = Map.fetch!(known, "action")

    if action in @allowed_actions do
      {:ok,
       %__MODULE__{
         tool: Map.fetch!(known, "tool"),
         action: action,
         context: Map.get(known, "context"),
         to: Map.get(known, "to"),
         matches: Map.get(known, "matches"),
         extra: extra
       }}
    else
      {:error, {:invalid_permission_rule, invalid_detail("action", action, @allowed_actions)}}
    end
  end

  defp invalid_detail(field, value, allowed) do
    %{message: "#{field} is invalid", path: [field], value: value, allowed: allowed}
  end
end

defmodule AmpSdk.Types.MCPServer do
  @moduledoc """
  Structured representation of an MCP server returned by `AmpSdk.mcp_list/1`.
  """

  alias AmpSdk.{Error, Schema}
  alias CliSubprocessCore.Schema.Conventions

  @enforce_keys [:name, :type, :source]
  @allowed_types ~w(command url)
  @allowed_sources ~w(global workspace)
  @known_fields ["name", "type", "source", "command", "args", "url"]
  @schema Zoi.map(
            %{
              "name" => Conventions.trimmed_string() |> Zoi.min(1),
              "type" => Conventions.trimmed_string() |> Zoi.min(1),
              "source" => Conventions.trimmed_string() |> Zoi.min(1),
              "command" => Conventions.optional_trimmed_string(),
              "args" => Conventions.string_list(),
              "url" => Conventions.optional_trimmed_string()
            },
            unrecognized_keys: :preserve
          )

  defstruct [:name, :type, :source, :command, :args, :url, extra: %{}]

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          source: String.t(),
          command: String.t() | nil,
          args: [String.t()],
          url: String.t() | nil,
          extra: map()
        }

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec parse(map() | t()) ::
          {:ok, t()} | {:error, {:invalid_mcp_server, CliSubprocessCore.Schema.error_detail()}}
  def parse(%__MODULE__{} = server), do: {:ok, server}

  def parse(map) when is_map(map) do
    case Schema.parse(@schema, map, :invalid_mcp_server) do
      {:ok, parsed} ->
        {known, extra} = Schema.split_extra(parsed, @known_fields)

        build_server(known, extra)

      {:error, {:invalid_mcp_server, details}} ->
        {:error, {:invalid_mcp_server, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = server), do: server

  def parse!(map) when is_map(map) do
    case parse(map) do
      {:ok, server} ->
        server

      {:error, {:invalid_mcp_server, details}} ->
        raise Error.new(:invalid_configuration, "Invalid MCP server", cause: details)
    end
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = server) do
    %{
      "name" => server.name,
      "type" => server.type,
      "source" => server.source,
      "command" => server.command,
      "args" => server.args,
      "url" => server.url
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(server.extra)
  end

  defp build_server(known, extra) do
    type = Map.fetch!(known, "type")
    source = Map.fetch!(known, "source")

    with :ok <- validate_member("type", type, @allowed_types),
         :ok <- validate_member("source", source, @allowed_sources) do
      {:ok,
       %__MODULE__{
         name: Map.fetch!(known, "name"),
         type: type,
         source: source,
         command: Map.get(known, "command"),
         args: Map.get(known, "args", []),
         url: Map.get(known, "url"),
         extra: extra
       }}
    else
      {:error, details} ->
        {:error, {:invalid_mcp_server, details}}
    end
  end

  defp validate_member(field, value, allowed) do
    if value in allowed do
      :ok
    else
      {:error, %{message: "#{field} is invalid", path: [field], value: value, allowed: allowed}}
    end
  end
end
