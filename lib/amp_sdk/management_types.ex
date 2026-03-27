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

  alias AmpSdk.Schema
  alias CliSubprocessCore.Schema.Conventions

  @enforce_keys [:tool, :action]
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

        {:ok,
         %__MODULE__{
           tool: Map.fetch!(known, "tool"),
           action: Map.fetch!(known, "action"),
           context: Map.get(known, "context"),
           to: Map.get(known, "to"),
           matches: Map.get(known, "matches"),
           extra: extra
         }}

      {:error, {:invalid_permission_rule, details}} ->
        {:error, {:invalid_permission_rule, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = rule), do: rule

  def parse!(map) when is_map(map) do
    parsed = Schema.parse!(@schema, map, :invalid_permission_rule)
    {known, extra} = Schema.split_extra(parsed, @known_fields)

    %__MODULE__{
      tool: Map.fetch!(known, "tool"),
      action: Map.fetch!(known, "action"),
      context: Map.get(known, "context"),
      to: Map.get(known, "to"),
      matches: Map.get(known, "matches"),
      extra: extra
    }
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
end

defmodule AmpSdk.Types.MCPServer do
  @moduledoc """
  Structured representation of an MCP server returned by `AmpSdk.mcp_list/1`.
  """

  alias AmpSdk.Schema
  alias CliSubprocessCore.Schema.Conventions

  @enforce_keys [:name, :type, :source]
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

        {:ok,
         %__MODULE__{
           name: Map.fetch!(known, "name"),
           type: Map.fetch!(known, "type"),
           source: Map.fetch!(known, "source"),
           command: Map.get(known, "command"),
           args: Map.get(known, "args", []),
           url: Map.get(known, "url"),
           extra: extra
         }}

      {:error, {:invalid_mcp_server, details}} ->
        {:error, {:invalid_mcp_server, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = server), do: server

  def parse!(map) when is_map(map) do
    parsed = Schema.parse!(@schema, map, :invalid_mcp_server)
    {known, extra} = Schema.split_extra(parsed, @known_fields)

    %__MODULE__{
      name: Map.fetch!(known, "name"),
      type: Map.fetch!(known, "type"),
      source: Map.fetch!(known, "source"),
      command: Map.get(known, "command"),
      args: Map.get(known, "args", []),
      url: Map.get(known, "url"),
      extra: extra
    }
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
end
