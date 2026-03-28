defmodule AmpSdk.Types do
  @moduledoc "Type definitions and structs for the Amp SDK."
  alias AmpSdk.{Config, Error}

  defmodule TextContent do
    @moduledoc "A text content block in a message."

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["type", "text"]
    @schema Message.text_content()

    @type t :: %__MODULE__{type: String.t(), text: String.t(), extra: map()}
    @derive {Jason.Encoder, only: [:type, :text]}
    defstruct type: "text", text: "", extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_text_content, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = content), do: {:ok, content}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_text_content) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             type: Map.get(known, "type", "text"),
             text: Map.get(known, "text", ""),
             extra: extra
           }}

        {:error, {:invalid_text_content, details}} ->
          {:error, {:invalid_text_content, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = content), do: content

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_text_content)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        type: Map.get(known, "type", "text"),
        text: Map.get(known, "text", ""),
        extra: extra
      }
    end

    @spec from_map(map()) :: t()
    def from_map(map), do: parse!(map)
  end

  defmodule ToolUseContent do
    @moduledoc "A tool use content block in an assistant message."

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["type", "id", "name", "input"]
    @schema Message.tool_use_content()

    @type t :: %__MODULE__{
            type: String.t(),
            id: String.t(),
            name: String.t(),
            input: map(),
            extra: map()
          }
    @derive {Jason.Encoder, only: [:type, :id, :name, :input]}
    defstruct type: "tool_use", id: "", name: "", input: %{}, extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_tool_use_content, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = content), do: {:ok, content}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_tool_use_content) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             type: Map.get(known, "type", "tool_use"),
             id: Map.get(known, "id", ""),
             name: Map.get(known, "name", ""),
             input: Map.get(known, "input", %{}),
             extra: extra
           }}

        {:error, {:invalid_tool_use_content, details}} ->
          {:error, {:invalid_tool_use_content, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = content), do: content

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_tool_use_content)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        type: Map.get(known, "type", "tool_use"),
        id: Map.get(known, "id", ""),
        name: Map.get(known, "name", ""),
        input: Map.get(known, "input", %{}),
        extra: extra
      }
    end

    @spec from_map(map()) :: t()
    def from_map(map), do: parse!(map)
  end

  defmodule ToolResultContent do
    @moduledoc "A tool result content block in a user message."
    @type t :: %__MODULE__{
            type: String.t(),
            tool_use_id: String.t(),
            content: String.t(),
            is_error: boolean(),
            extra: map()
          }
    @derive {Jason.Encoder, only: [:type, :tool_use_id, :content, :is_error]}

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["type", "tool_use_id", "content", "is_error"]
    @schema Message.tool_result_content()

    defstruct type: "tool_result", tool_use_id: "", content: "", is_error: false, extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_tool_result_content, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = content), do: {:ok, content}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_tool_result_content) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             type: Map.get(known, "type", "tool_result"),
             tool_use_id: Map.get(known, "tool_use_id", ""),
             content: Map.get(known, "content", ""),
             is_error: Map.get(known, "is_error", false),
             extra: extra
           }}

        {:error, {:invalid_tool_result_content, details}} ->
          {:error, {:invalid_tool_result_content, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = content), do: content

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_tool_result_content)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        type: Map.get(known, "type", "tool_result"),
        tool_use_id: Map.get(known, "tool_use_id", ""),
        content: Map.get(known, "content", ""),
        is_error: Map.get(known, "is_error", false),
        extra: extra
      }
    end

    @spec from_map(map()) :: t()
    def from_map(map), do: parse!(map)
  end

  defmodule ThinkingContent do
    @moduledoc "A thinking content block in an assistant message."
    @type t :: %__MODULE__{type: String.t(), thinking: String.t(), extra: map()}
    @derive {Jason.Encoder, only: [:type, :thinking]}

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["type", "thinking"]
    @schema Message.thinking_content()

    defstruct type: "thinking", thinking: "", extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_thinking_content, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = content), do: {:ok, content}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_thinking_content) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             type: Map.get(known, "type", "thinking"),
             thinking: Map.get(known, "thinking", ""),
             extra: extra
           }}

        {:error, {:invalid_thinking_content, details}} ->
          {:error, {:invalid_thinking_content, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = content), do: content

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_thinking_content)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        type: Map.get(known, "type", "thinking"),
        thinking: Map.get(known, "thinking", ""),
        extra: extra
      }
    end

    @spec from_map(map()) :: t()
    def from_map(map), do: parse!(map)
  end

  defmodule Usage do
    @moduledoc "Token usage statistics for a message or session."
    @type t :: %__MODULE__{
            input_tokens: non_neg_integer(),
            output_tokens: non_neg_integer(),
            cache_creation_input_tokens: non_neg_integer(),
            cache_read_input_tokens: non_neg_integer(),
            service_tier: String.t() | nil,
            extra: map()
          }
    @derive {Jason.Encoder,
             only: [
               :input_tokens,
               :output_tokens,
               :cache_creation_input_tokens,
               :cache_read_input_tokens,
               :service_tier
             ]}

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields [
      "input_tokens",
      "output_tokens",
      "cache_creation_input_tokens",
      "cache_read_input_tokens",
      "service_tier"
    ]
    @schema Message.usage()

    defstruct input_tokens: 0,
              output_tokens: 0,
              cache_creation_input_tokens: 0,
              cache_read_input_tokens: 0,
              service_tier: nil,
              extra: %{}

    def from_map(nil), do: nil

    def from_map(map) when is_map(map) do
      parse!(map)
    end

    @spec parse(map() | t() | nil) ::
            {:ok, t() | nil} | {:error, {:invalid_usage, CliSubprocessCore.Schema.error_detail()}}
    def parse(nil), do: {:ok, nil}
    def parse(%__MODULE__{} = usage), do: {:ok, usage}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_usage) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             input_tokens: Map.get(known, "input_tokens", 0),
             output_tokens: Map.get(known, "output_tokens", 0),
             cache_creation_input_tokens: Map.get(known, "cache_creation_input_tokens", 0),
             cache_read_input_tokens: Map.get(known, "cache_read_input_tokens", 0),
             service_tier: Map.get(known, "service_tier"),
             extra: extra
           }}

        {:error, {:invalid_usage, details}} ->
          {:error, {:invalid_usage, details}}
      end
    end

    @spec parse!(map() | t() | nil) :: t() | nil
    def parse!(nil), do: nil
    def parse!(%__MODULE__{} = usage), do: usage

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_usage)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        input_tokens: Map.get(known, "input_tokens", 0),
        output_tokens: Map.get(known, "output_tokens", 0),
        cache_creation_input_tokens: Map.get(known, "cache_creation_input_tokens", 0),
        cache_read_input_tokens: Map.get(known, "cache_read_input_tokens", 0),
        service_tier: Map.get(known, "service_tier"),
        extra: extra
      }
    end
  end

  defmodule MCPServerStatus do
    @moduledoc "Status of an MCP server connection."

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["name", "status"]
    @schema Message.mcp_server_status()

    @type t :: %__MODULE__{name: String.t(), status: String.t(), extra: map()}
    @derive {Jason.Encoder, only: [:name, :status]}
    defstruct name: "", status: "", extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_mcp_server_status, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = status), do: {:ok, status}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_mcp_server_status) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             name: Map.get(known, "name", ""),
             status: Map.get(known, "status", ""),
             extra: extra
           }}

        {:error, {:invalid_mcp_server_status, details}} ->
          {:error, {:invalid_mcp_server_status, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = status), do: status

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_mcp_server_status)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        name: Map.get(known, "name", ""),
        status: Map.get(known, "status", ""),
        extra: extra
      }
    end

    @spec from_map(map()) :: t()
    def from_map(map), do: parse!(map)
  end

  defmodule AssistantPayload do
    @moduledoc "Structured payload for assistant stream messages."
    @type t :: %__MODULE__{
            id: String.t() | nil,
            role: String.t(),
            model: String.t() | nil,
            content: [TextContent.t() | ThinkingContent.t() | ToolUseContent.t() | map()],
            stop_reason: String.t() | nil,
            stop_sequence: String.t() | nil,
            usage: Usage.t() | nil,
            extra: map()
          }

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["id", "role", "model", "content", "stop_reason", "stop_sequence", "usage"]
    @schema Message.assistant_payload()

    @derive {Jason.Encoder,
             only: [:id, :role, :model, :content, :stop_reason, :stop_sequence, :usage]}
    defstruct id: nil,
              role: "assistant",
              model: nil,
              content: [],
              stop_reason: nil,
              stop_sequence: nil,
              usage: nil,
              extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_assistant_payload, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = payload), do: {:ok, payload}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_assistant_payload) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             id: Map.get(known, "id"),
             role: Map.get(known, "role", "assistant"),
             model: Map.get(known, "model"),
             content: Enum.map(Map.get(known, "content", []), &parse_assistant_content/1),
             stop_reason: Map.get(known, "stop_reason"),
             stop_sequence: Map.get(known, "stop_sequence"),
             usage: Usage.parse!(Map.get(known, "usage")),
             extra: extra
           }}

        {:error, {:invalid_assistant_payload, details}} ->
          {:error, {:invalid_assistant_payload, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = payload), do: payload

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_assistant_payload)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        id: Map.get(known, "id"),
        role: Map.get(known, "role", "assistant"),
        model: Map.get(known, "model"),
        content: Enum.map(Map.get(known, "content", []), &parse_assistant_content/1),
        stop_reason: Map.get(known, "stop_reason"),
        stop_sequence: Map.get(known, "stop_sequence"),
        usage: Usage.parse!(Map.get(known, "usage")),
        extra: extra
      }
    end

    defp parse_assistant_content(%{"type" => "text"} = content), do: TextContent.parse!(content)

    defp parse_assistant_content(%{"type" => "thinking"} = content),
      do: ThinkingContent.parse!(content)

    defp parse_assistant_content(%{"type" => "tool_use"} = content),
      do: ToolUseContent.parse!(content)

    defp parse_assistant_content(other), do: other
  end

  defmodule UserPayload do
    @moduledoc "Structured payload for user stream messages."
    @type t :: %__MODULE__{
            role: String.t(),
            content: [TextContent.t() | ToolResultContent.t() | map()],
            extra: map()
          }

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["role", "content"]
    @schema Message.user_payload()

    @derive {Jason.Encoder, only: [:role, :content]}
    defstruct role: "user", content: [], extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_user_payload, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = payload), do: {:ok, payload}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_user_payload) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             role: Map.get(known, "role", "user"),
             content: Enum.map(Map.get(known, "content", []), &parse_user_content/1),
             extra: extra
           }}

        {:error, {:invalid_user_payload, details}} ->
          {:error, {:invalid_user_payload, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = payload), do: payload

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_user_payload)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        role: Map.get(known, "role", "user"),
        content: Enum.map(Map.get(known, "content", []), &parse_user_content/1),
        extra: extra
      }
    end

    defp parse_user_content(%{"type" => "text"} = content), do: TextContent.parse!(content)

    defp parse_user_content(%{"type" => "tool_result"} = content),
      do: ToolResultContent.parse!(content)

    defp parse_user_content(other), do: other
  end

  defmodule SystemMessage do
    @moduledoc "A system initialization message from the CLI."
    @type t :: %__MODULE__{
            type: String.t(),
            subtype: String.t(),
            session_id: String.t(),
            cwd: String.t(),
            tools: [String.t()],
            mcp_servers: [MCPServerStatus.t()],
            extra: map()
          }

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["type", "subtype", "session_id", "cwd", "tools", "mcp_servers"]
    @schema Message.system_message()

    defstruct type: "system",
              subtype: "init",
              session_id: "",
              cwd: "",
              tools: [],
              mcp_servers: [],
              extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_system_message, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = message), do: {:ok, message}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_system_message) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             type: Map.get(known, "type", "system"),
             subtype: Map.get(known, "subtype", "init"),
             session_id: Map.get(known, "session_id", ""),
             cwd: Map.get(known, "cwd", ""),
             tools: Map.get(known, "tools", []),
             mcp_servers: Enum.map(Map.get(known, "mcp_servers", []), &MCPServerStatus.parse!/1),
             extra: extra
           }}

        {:error, {:invalid_system_message, details}} ->
          {:error, {:invalid_system_message, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = message), do: message

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_system_message)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        type: Map.get(known, "type", "system"),
        subtype: Map.get(known, "subtype", "init"),
        session_id: Map.get(known, "session_id", ""),
        cwd: Map.get(known, "cwd", ""),
        tools: Map.get(known, "tools", []),
        mcp_servers: Enum.map(Map.get(known, "mcp_servers", []), &MCPServerStatus.parse!/1),
        extra: extra
      }
    end

    def from_map(map) when is_map(map) do
      parse!(map)
    end
  end

  defmodule AssistantMessage do
    @moduledoc "An assistant response message from the CLI."
    @type t :: %__MODULE__{
            type: String.t(),
            session_id: String.t(),
            message: AssistantPayload.t(),
            parent_tool_use_id: String.t() | nil,
            extra: map()
          }

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["type", "session_id", "message", "parent_tool_use_id"]
    @schema Message.assistant_message()

    defstruct type: "assistant",
              session_id: "",
              message: %AssistantPayload{},
              parent_tool_use_id: nil,
              extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_assistant_message, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = message), do: {:ok, message}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_assistant_message) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             type: Map.get(known, "type", "assistant"),
             session_id: Map.get(known, "session_id", ""),
             message: AssistantPayload.parse!(Map.get(known, "message", %{})),
             parent_tool_use_id: Map.get(known, "parent_tool_use_id"),
             extra: extra
           }}

        {:error, {:invalid_assistant_message, details}} ->
          {:error, {:invalid_assistant_message, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = message), do: message

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_assistant_message)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        type: Map.get(known, "type", "assistant"),
        session_id: Map.get(known, "session_id", ""),
        message: AssistantPayload.parse!(Map.get(known, "message", %{})),
        parent_tool_use_id: Map.get(known, "parent_tool_use_id"),
        extra: extra
      }
    end

    def from_map(map) when is_map(map) do
      parse!(map)
    end
  end

  defmodule UserMessage do
    @moduledoc "A user message in the conversation stream."
    @type t :: %__MODULE__{
            type: String.t(),
            session_id: String.t(),
            message: UserPayload.t(),
            parent_tool_use_id: String.t() | nil,
            extra: map()
          }

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields ["type", "session_id", "message", "parent_tool_use_id"]
    @schema Message.user_message()

    defstruct type: "user",
              session_id: "",
              message: %UserPayload{},
              parent_tool_use_id: nil,
              extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_user_message, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = message), do: {:ok, message}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_user_message) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             type: Map.get(known, "type", "user"),
             session_id: Map.get(known, "session_id", ""),
             message: UserPayload.parse!(Map.get(known, "message", %{})),
             parent_tool_use_id: Map.get(known, "parent_tool_use_id"),
             extra: extra
           }}

        {:error, {:invalid_user_message, details}} ->
          {:error, {:invalid_user_message, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = message), do: message

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_user_message)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        type: Map.get(known, "type", "user"),
        session_id: Map.get(known, "session_id", ""),
        message: UserPayload.parse!(Map.get(known, "message", %{})),
        parent_tool_use_id: Map.get(known, "parent_tool_use_id"),
        extra: extra
      }
    end

    def from_map(map) when is_map(map) do
      parse!(map)
    end
  end

  defmodule ResultMessage do
    @moduledoc "A successful result message indicating session completion."
    @type t :: %__MODULE__{
            type: String.t(),
            subtype: String.t(),
            session_id: String.t(),
            is_error: boolean(),
            result: String.t(),
            duration_ms: non_neg_integer(),
            num_turns: non_neg_integer(),
            usage: Usage.t() | nil,
            permission_denials: [String.t()] | nil,
            extra: map()
          }

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields [
      "type",
      "subtype",
      "session_id",
      "is_error",
      "result",
      "duration_ms",
      "num_turns",
      "usage",
      "permission_denials"
    ]
    @schema Message.result_message()

    defstruct type: "result",
              subtype: "success",
              session_id: "",
              is_error: false,
              result: "",
              duration_ms: 0,
              num_turns: 0,
              usage: nil,
              permission_denials: nil,
              extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_result_message, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = message), do: {:ok, message}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_result_message) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             type: Map.get(known, "type", "result"),
             subtype: Map.get(known, "subtype", "success"),
             session_id: Map.get(known, "session_id", ""),
             is_error: Map.get(known, "is_error", false),
             result: Map.get(known, "result", ""),
             duration_ms: Map.get(known, "duration_ms", 0),
             num_turns: Map.get(known, "num_turns", 0),
             usage: Usage.parse!(Map.get(known, "usage")),
             permission_denials: Map.get(known, "permission_denials"),
             extra: extra
           }}

        {:error, {:invalid_result_message, details}} ->
          {:error, {:invalid_result_message, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = message), do: message

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_result_message)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        type: Map.get(known, "type", "result"),
        subtype: Map.get(known, "subtype", "success"),
        session_id: Map.get(known, "session_id", ""),
        is_error: Map.get(known, "is_error", false),
        result: Map.get(known, "result", ""),
        duration_ms: Map.get(known, "duration_ms", 0),
        num_turns: Map.get(known, "num_turns", 0),
        usage: Usage.parse!(Map.get(known, "usage")),
        permission_denials: Map.get(known, "permission_denials"),
        extra: extra
      }
    end

    def from_map(map) when is_map(map) do
      parse!(map)
    end
  end

  defmodule ErrorResultMessage do
    @moduledoc "An error result message indicating session failure."
    @type t :: %__MODULE__{
            type: String.t(),
            subtype: String.t(),
            session_id: String.t(),
            is_error: boolean(),
            error: String.t(),
            kind: atom() | String.t() | nil,
            details: map() | nil,
            exit_code: integer() | nil,
            stderr: String.t() | nil,
            stderr_truncated?: boolean(),
            duration_ms: non_neg_integer(),
            num_turns: non_neg_integer(),
            usage: Usage.t() | nil,
            permission_denials: [String.t()] | nil,
            extra: map()
          }

    alias AmpSdk.Schema
    alias AmpSdk.Schema.Message

    @known_fields [
      "type",
      "subtype",
      "session_id",
      "is_error",
      "error",
      "kind",
      "details",
      "exit_code",
      "stderr",
      "stderr_truncated?",
      "duration_ms",
      "num_turns",
      "usage",
      "permission_denials"
    ]
    @schema Message.error_result_message()

    defstruct type: "result",
              subtype: "error_during_execution",
              session_id: "",
              is_error: true,
              error: "",
              kind: nil,
              details: nil,
              exit_code: nil,
              stderr: nil,
              stderr_truncated?: false,
              duration_ms: 0,
              num_turns: 0,
              usage: nil,
              permission_denials: nil,
              extra: %{}

    @spec parse(map() | t()) ::
            {:ok, t()}
            | {:error, {:invalid_error_result_message, CliSubprocessCore.Schema.error_detail()}}
    def parse(%__MODULE__{} = message), do: {:ok, message}

    def parse(map) when is_map(map) do
      case Schema.parse(@schema, map, :invalid_error_result_message) do
        {:ok, parsed} ->
          {known, extra} = Schema.split_extra(parsed, @known_fields)

          {:ok,
           %__MODULE__{
             type: Map.get(known, "type", "result"),
             subtype: Map.get(known, "subtype", "error_during_execution"),
             session_id: Map.get(known, "session_id", ""),
             is_error: true,
             error: Map.get(known, "error", ""),
             kind: Map.get(known, "kind"),
             details: Map.get(known, "details"),
             exit_code: Map.get(known, "exit_code"),
             stderr: Map.get(known, "stderr"),
             stderr_truncated?: Map.get(known, "stderr_truncated?", false),
             duration_ms: Map.get(known, "duration_ms", 0),
             num_turns: Map.get(known, "num_turns", 0),
             usage: Usage.parse!(Map.get(known, "usage")),
             permission_denials: Map.get(known, "permission_denials"),
             extra: extra
           }}

        {:error, {:invalid_error_result_message, details}} ->
          {:error, {:invalid_error_result_message, details}}
      end
    end

    @spec parse!(map() | t()) :: t()
    def parse!(%__MODULE__{} = message), do: message

    def parse!(map) when is_map(map) do
      parsed = Schema.parse!(@schema, map, :invalid_error_result_message)
      {known, extra} = Schema.split_extra(parsed, @known_fields)

      %__MODULE__{
        type: Map.get(known, "type", "result"),
        subtype: Map.get(known, "subtype", "error_during_execution"),
        session_id: Map.get(known, "session_id", ""),
        is_error: true,
        error: Map.get(known, "error", ""),
        kind: Map.get(known, "kind"),
        details: Map.get(known, "details"),
        exit_code: Map.get(known, "exit_code"),
        stderr: Map.get(known, "stderr"),
        stderr_truncated?: Map.get(known, "stderr_truncated?", false),
        duration_ms: Map.get(known, "duration_ms", 0),
        num_turns: Map.get(known, "num_turns", 0),
        usage: Usage.parse!(Map.get(known, "usage")),
        permission_denials: Map.get(known, "permission_denials"),
        extra: extra
      }
    end

    def from_map(map) when is_map(map) do
      parse!(map)
    end
  end

  defmodule UserInputMessage do
    @moduledoc "A user input message to send to the CLI."
    @type t :: %__MODULE__{type: String.t(), message: UserPayload.t()}
    @derive Jason.Encoder
    defstruct type: "user", message: %UserPayload{}
  end

  defmodule Permission do
    @moduledoc "A tool permission rule for the CLI session."
    @type t :: %__MODULE__{
            tool: String.t(),
            action: String.t(),
            matches: map() | nil,
            context: String.t() | nil,
            to: String.t() | nil
          }
    @derive Jason.Encoder
    @enforce_keys [:tool, :action]
    defstruct [:tool, :action, :matches, :context, :to]

    @spec new(String.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
    def new(tool, action, opts \\ [])

    def new(tool, action, opts)
        when is_binary(tool) and is_binary(action) and is_list(opts) do
      with :ok <- validate_tool(tool),
           :ok <- validate_action(action),
           :ok <- validate_delegate_options(action, opts) do
        {:ok,
         %__MODULE__{
           tool: tool,
           action: action,
           matches: Keyword.get(opts, :matches),
           context: Keyword.get(opts, :context),
           to: Keyword.get(opts, :to)
         }}
      end
    end

    def new(_tool, _action, _opts) do
      {:error, Error.new(:invalid_configuration, "Permission requires string tool and action")}
    end

    @spec new!(String.t(), String.t(), keyword()) :: t()
    def new!(tool, action, opts \\ []) do
      case new(tool, action, opts) do
        {:ok, permission} -> permission
        {:error, error} -> raise error
      end
    end

    defp validate_tool(tool) do
      if String.trim(tool) == "" do
        {:error, Error.new(:invalid_configuration, "Permission tool cannot be empty")}
      else
        :ok
      end
    end

    defp validate_action(action) do
      if String.trim(action) == "" do
        {:error, Error.new(:invalid_configuration, "Permission action cannot be empty")}
      else
        :ok
      end
    end

    defp validate_delegate_options("delegate", opts) do
      if Keyword.has_key?(opts, :to) do
        :ok
      else
        {:error, Error.new(:invalid_configuration, ~s(delegate action requires "to" option))}
      end
    end

    defp validate_delegate_options(_action, opts) do
      if Keyword.has_key?(opts, :to) do
        {:error,
         Error.new(:invalid_configuration, ~s("to" option only allowed with delegate action))}
      else
        :ok
      end
    end
  end

  defmodule MCPStdioServer do
    @moduledoc "Configuration for an MCP server using stdio transport."
    @type t :: %__MODULE__{
            command: String.t(),
            args: [String.t()],
            env: map(),
            disabled: boolean()
          }
    @derive Jason.Encoder
    @enforce_keys [:command]
    defstruct command: "", args: [], env: %{}, disabled: false

    @spec new(map() | keyword()) :: {:ok, t()} | {:error, Error.t()}
    def new(opts) when is_map(opts) or is_list(opts) do
      opts = Config.normalize_opts(opts)

      with {:ok, command} <- fetch_command(opts),
           {:ok, args} <- fetch_args(opts),
           {:ok, env} <- fetch_env(opts),
           {:ok, disabled} <- Config.fetch_option(opts, :disabled, false) do
        {:ok,
         %__MODULE__{
           command: command,
           args: Enum.map(args, &to_string/1),
           env: Config.normalize_string_map(env),
           disabled: !!disabled
         }}
      end
    end

    def new(_opts) do
      {:error, Error.new(:invalid_configuration, "MCP stdio config must be map or keyword")}
    end

    @spec new!(map() | keyword()) :: t()
    def new!(opts) do
      case new(opts) do
        {:ok, server} -> server
        {:error, error} -> raise error
      end
    end

    defp fetch_command(opts) do
      with {:ok, command} <- Config.fetch_option(opts, :command) do
        if is_binary(command) and String.trim(command) != "" do
          {:ok, command}
        else
          {:error, Error.new(:invalid_configuration, "MCP stdio command cannot be empty")}
        end
      end
    end

    defp fetch_args(opts) do
      with {:ok, args} <- Config.fetch_option(opts, :args, []) do
        if is_list(args) do
          {:ok, args}
        else
          {:error, Error.new(:invalid_configuration, "MCP stdio args must be a list")}
        end
      end
    end

    defp fetch_env(opts) do
      with {:ok, env} <- Config.fetch_option(opts, :env, %{}) do
        if is_map(env) or is_list(env) do
          {:ok, env}
        else
          {:error, Error.new(:invalid_configuration, "MCP stdio env must be map or keyword")}
        end
      end
    end
  end

  defmodule MCPHttpServer do
    @moduledoc "Configuration for an MCP server using HTTP transport."
    @type t :: %__MODULE__{
            url: String.t(),
            headers: map(),
            transport: String.t() | nil,
            disabled: boolean()
          }
    @derive Jason.Encoder
    @enforce_keys [:url]
    defstruct url: "", headers: %{}, transport: nil, disabled: false

    @spec new(map() | keyword()) :: {:ok, t()} | {:error, Error.t()}
    def new(opts) when is_map(opts) or is_list(opts) do
      opts = Config.normalize_opts(opts)

      with {:ok, url} <- fetch_url(opts),
           {:ok, headers} <- fetch_headers(opts),
           {:ok, transport} <- fetch_transport(opts),
           {:ok, disabled} <- Config.fetch_option(opts, :disabled, false) do
        {:ok,
         %__MODULE__{
           url: url,
           headers: Config.normalize_string_map(headers),
           transport: transport,
           disabled: !!disabled
         }}
      end
    end

    def new(_opts) do
      {:error, Error.new(:invalid_configuration, "MCP HTTP config must be map or keyword")}
    end

    @spec new!(map() | keyword()) :: t()
    def new!(opts) do
      case new(opts) do
        {:ok, server} -> server
        {:error, error} -> raise error
      end
    end

    defp fetch_url(opts) do
      with {:ok, url} <- Config.fetch_option(opts, :url) do
        if is_binary(url) and String.trim(url) != "" do
          {:ok, url}
        else
          {:error, Error.new(:invalid_configuration, "MCP HTTP url cannot be empty")}
        end
      end
    end

    defp fetch_headers(opts) do
      with {:ok, headers} <- Config.fetch_option(opts, :headers, %{}) do
        if is_map(headers) or is_list(headers) do
          {:ok, headers}
        else
          {:error, Error.new(:invalid_configuration, "MCP HTTP headers must be map or keyword")}
        end
      end
    end

    defp fetch_transport(opts) do
      with {:ok, transport} <- Config.fetch_option(opts, :transport) do
        if is_nil(transport) or is_binary(transport) do
          {:ok, transport}
        else
          {:error, Error.new(:invalid_configuration, "MCP HTTP transport must be a string")}
        end
      end
    end
  end

  defmodule Options do
    @moduledoc "Configuration options for an Amp CLI session."
    @stream_timeout_ms AmpSdk.Defaults.stream_timeout_ms()
    alias CliSubprocessCore.{ExecutionSurface, ModelInput}

    @type t :: %__MODULE__{
            cwd: String.t() | nil,
            mode: String.t(),
            dangerously_allow_all: boolean(),
            visibility: String.t() | nil,
            settings_file: String.t() | nil,
            log_level: String.t() | nil,
            log_file: String.t() | nil,
            env: map(),
            continue_thread: boolean() | String.t() | nil,
            mcp_config: map() | String.t() | nil,
            toolbox: String.t() | nil,
            skills: String.t() | nil,
            permissions: [Permission.t()] | nil,
            labels: [String.t()] | nil,
            thinking: boolean(),
            model_payload: CliSubprocessCore.ModelRegistry.selection() | map() | nil,
            execution_surface: ExecutionSurface.t() | nil,
            stream_timeout_ms: pos_integer(),
            max_stderr_buffer_bytes: pos_integer(),
            no_ide: boolean(),
            no_notifications: boolean(),
            no_color: boolean(),
            no_jetbrains: boolean()
          }
    defstruct cwd: nil,
              mode: "smart",
              dangerously_allow_all: false,
              visibility: "workspace",
              settings_file: nil,
              log_level: nil,
              log_file: nil,
              env: %{},
              continue_thread: nil,
              mcp_config: nil,
              toolbox: nil,
              skills: nil,
              permissions: nil,
              labels: nil,
              thinking: false,
              model_payload: nil,
              execution_surface: nil,
              stream_timeout_ms: @stream_timeout_ms,
              max_stderr_buffer_bytes: AmpSdk.Defaults.stream_max_stderr_buffer_bytes(),
              no_ide: false,
              no_notifications: false,
              no_color: false,
              no_jetbrains: false

    @spec validate!(t()) :: t()
    def validate!(%__MODULE__{} = options) do
      options
      |> validate_positive_integer!(:stream_timeout_ms)
      |> validate_positive_integer!(:max_stderr_buffer_bytes)
      |> normalize_model_payload!()
      |> normalize_execution_surface!()
    end

    @spec execution_surface_opts(t()) :: keyword()
    def execution_surface_opts(%__MODULE__{} = options) do
      case Map.get(options, :execution_surface, nil) do
        nil ->
          []

        %ExecutionSurface{} = surface ->
          [transport_options: surface.transport_options] ++
            ExecutionSurface.surface_metadata(surface)
      end
    end

    defp normalize_model_payload!(%__MODULE__{model_payload: nil} = options), do: options

    defp normalize_model_payload!(%__MODULE__{} = options) do
      case ModelInput.normalize(:amp, %{model_payload: options.model_payload}) do
        {:ok, normalized} ->
          %{options | model_payload: normalized.selection}

        {:error, reason} ->
          raise ArgumentError, "model resolution failed for :amp: #{inspect(reason)}"
      end
    end

    defp normalize_execution_surface!(%__MODULE__{} = options) do
      case Map.get(options, :execution_surface, nil) do
        nil ->
          Map.put(options, :execution_surface, nil)

        %ExecutionSurface{} = surface ->
          case ExecutionSurface.new(
                 transport_options: surface.transport_options,
                 surface_kind: surface.surface_kind,
                 target_id: surface.target_id,
                 lease_ref: surface.lease_ref,
                 surface_ref: surface.surface_ref,
                 boundary_class: surface.boundary_class,
                 observability: surface.observability
               ) do
            {:ok, %ExecutionSurface{} = normalized} ->
              %{options | execution_surface: normalized}

            {:error, reason} ->
              raise ArgumentError, "execution_surface is invalid: #{inspect(reason)}"
          end

        execution_surface ->
          raise ArgumentError,
                "execution_surface must be a %CliSubprocessCore.ExecutionSurface{}, got: #{inspect(execution_surface)}"
      end
    end

    defp validate_positive_integer!(%__MODULE__{} = options, field) when is_atom(field) do
      case Map.fetch!(options, field) do
        value when is_integer(value) and value > 0 ->
          options

        value ->
          raise ArgumentError,
                "#{field} must be a positive integer, got: #{inspect(value)}"
      end
    end
  end

  @type stream_message ::
          SystemMessage.t()
          | AssistantMessage.t()
          | UserMessage.t()
          | ResultMessage.t()
          | ErrorResultMessage.t()

  @message_types %{
    "system" => SystemMessage,
    "assistant" => AssistantMessage,
    "user" => UserMessage
  }

  @spec parse_stream_message(String.t()) :: {:ok, stream_message()} | {:error, Error.t()}
  def parse_stream_message(json_line) when is_binary(json_line) do
    with {:ok, data} <- Jason.decode(json_line),
         {:ok, message} <- parse_message_data(data) do
      {:ok, message}
    else
      {:error, %Error{} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error,
         Error.new(:parse_error, "Invalid JSON stream message",
           cause: reason,
           details: json_line
         )}
    end
  end

  @spec parse_message_data(map()) :: {:ok, stream_message()} | {:error, Error.t()}
  def parse_message_data(%{"type" => "result", "is_error" => true} = data) do
    parse_typed_message(ErrorResultMessage, data)
  end

  def parse_message_data(%{"type" => "result"} = data) do
    parse_typed_message(ResultMessage, data)
  end

  def parse_message_data(%{"type" => type} = data) when is_map_key(@message_types, type) do
    module = Map.fetch!(@message_types, type)
    parse_typed_message(module, data)
  end

  def parse_message_data(%{"type" => type}) do
    {:error, Error.new(:invalid_message, "Unknown message type: #{type}", cause: type)}
  end

  def parse_message_data(_) do
    {:error,
     Error.new(:invalid_message, "Missing message type field", cause: :missing_type_field)}
  end

  @spec final_message?(stream_message()) :: boolean()
  def final_message?(%ResultMessage{}), do: true
  def final_message?(%ErrorResultMessage{}), do: true
  def final_message?(_), do: false

  @spec session_id(stream_message()) :: String.t() | nil
  def session_id(%SystemMessage{session_id: session_id}), do: normalize_session_id(session_id)
  def session_id(%AssistantMessage{session_id: session_id}), do: normalize_session_id(session_id)
  def session_id(%UserMessage{session_id: session_id}), do: normalize_session_id(session_id)
  def session_id(%ResultMessage{session_id: session_id}), do: normalize_session_id(session_id)

  def session_id(%ErrorResultMessage{session_id: session_id}),
    do: normalize_session_id(session_id)

  @spec create_user_message(String.t()) :: UserInputMessage.t()
  def create_user_message(text) when is_binary(text) do
    %UserInputMessage{
      type: "user",
      message: %UserPayload{
        role: "user",
        content: [%TextContent{type: "text", text: text}]
      }
    }
  end

  defp normalize_session_id(session_id)
       when is_binary(session_id) and session_id not in ["", "nil"],
       do: session_id

  defp normalize_session_id(_session_id), do: nil

  defp parse_typed_message(module, data) when is_atom(module) and is_map(data) do
    case module.parse(data) do
      {:ok, message} ->
        {:ok, message}

      {:error, {tag, details}} ->
        {:error,
         Error.new(:invalid_message, details.message, cause: tag, context: %{validation: details})}
    end
  end
end
