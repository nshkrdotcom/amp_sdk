defmodule AmpSdk.Types.ThreadSummary do
  @moduledoc """
  Structured representation of a thread entry returned by `AmpSdk.threads_list/1`.
  """

  @enforce_keys [:id, :title, :last_updated, :visibility, :messages]
  defstruct [:id, :title, :last_updated, :visibility, :messages, :raw]

  @type visibility :: :private | :public | :workspace | :group | :unknown

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          last_updated: String.t(),
          visibility: visibility(),
          messages: non_neg_integer(),
          raw: String.t() | nil
        }
end

defmodule AmpSdk.Types.PermissionRule do
  @moduledoc """
  Structured representation of a permission rule returned by `AmpSdk.permissions_list/1`.
  """

  @enforce_keys [:tool, :action]
  defstruct [:tool, :action, :context, :to, :matches, :raw]

  @type t :: %__MODULE__{
          tool: String.t(),
          action: String.t(),
          context: String.t() | nil,
          to: String.t() | nil,
          matches: map() | nil,
          raw: map() | nil
        }
end

defmodule AmpSdk.Types.MCPServer do
  @moduledoc """
  Structured representation of an MCP server returned by `AmpSdk.mcp_list/1`.
  """

  @enforce_keys [:name, :type, :source]
  defstruct [:name, :type, :source, :command, :args, :url, :raw]

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          source: String.t(),
          command: String.t() | nil,
          args: [String.t()],
          url: String.t() | nil,
          raw: map() | nil
        }
end
