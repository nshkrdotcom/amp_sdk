defmodule AmpSdk.Types do
  @moduledoc "Type definitions and structs for the Amp SDK."
  alias AmpSdk.{Config, Error}

  defmodule TextContent do
    @moduledoc "A text content block in a message."
    @type t :: %__MODULE__{type: String.t(), text: String.t()}
    @derive Jason.Encoder
    defstruct type: "text", text: ""
  end

  defmodule ToolUseContent do
    @moduledoc "A tool use content block in an assistant message."
    @type t :: %__MODULE__{type: String.t(), id: String.t(), name: String.t(), input: map()}
    @derive Jason.Encoder
    defstruct type: "tool_use", id: "", name: "", input: %{}
  end

  defmodule ToolResultContent do
    @moduledoc "A tool result content block in a user message."
    @type t :: %__MODULE__{
            type: String.t(),
            tool_use_id: String.t(),
            content: String.t(),
            is_error: boolean()
          }
    @derive Jason.Encoder
    defstruct type: "tool_result", tool_use_id: "", content: "", is_error: false
  end

  defmodule ThinkingContent do
    @moduledoc "A thinking content block in an assistant message."
    @type t :: %__MODULE__{type: String.t(), thinking: String.t()}
    @derive Jason.Encoder
    defstruct type: "thinking", thinking: ""
  end

  defmodule Usage do
    @moduledoc "Token usage statistics for a message or session."
    @type t :: %__MODULE__{
            input_tokens: non_neg_integer(),
            output_tokens: non_neg_integer(),
            cache_creation_input_tokens: non_neg_integer(),
            cache_read_input_tokens: non_neg_integer(),
            service_tier: String.t() | nil
          }
    @derive Jason.Encoder
    defstruct input_tokens: 0,
              output_tokens: 0,
              cache_creation_input_tokens: 0,
              cache_read_input_tokens: 0,
              service_tier: nil

    def from_map(nil), do: nil

    def from_map(map) when is_map(map) do
      %__MODULE__{
        input_tokens: map["input_tokens"] || 0,
        output_tokens: map["output_tokens"] || 0,
        cache_creation_input_tokens: map["cache_creation_input_tokens"] || 0,
        cache_read_input_tokens: map["cache_read_input_tokens"] || 0,
        service_tier: map["service_tier"]
      }
    end
  end

  defmodule MCPServerStatus do
    @moduledoc "Status of an MCP server connection."
    @type t :: %__MODULE__{name: String.t(), status: String.t()}
    @derive Jason.Encoder
    defstruct name: "", status: ""
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
            usage: Usage.t() | nil
          }
    @derive Jason.Encoder
    defstruct id: nil,
              role: "assistant",
              model: nil,
              content: [],
              stop_reason: nil,
              stop_sequence: nil,
              usage: nil
  end

  defmodule UserPayload do
    @moduledoc "Structured payload for user stream messages."
    @type t :: %__MODULE__{
            role: String.t(),
            content: [TextContent.t() | ToolResultContent.t() | map()]
          }
    @derive Jason.Encoder
    defstruct role: "user", content: []
  end

  defmodule SystemMessage do
    @moduledoc "A system initialization message from the CLI."
    @type t :: %__MODULE__{
            type: String.t(),
            subtype: String.t(),
            session_id: String.t(),
            cwd: String.t(),
            tools: [String.t()],
            mcp_servers: [MCPServerStatus.t()]
          }
    defstruct type: "system",
              subtype: "init",
              session_id: "",
              cwd: "",
              tools: [],
              mcp_servers: []

    def from_map(map) when is_map(map) do
      %__MODULE__{
        type: map["type"] || "system",
        subtype: map["subtype"] || "init",
        session_id: map["session_id"] || "",
        cwd: map["cwd"] || "",
        tools: map["tools"] || [],
        mcp_servers:
          Enum.map(map["mcp_servers"] || [], fn s ->
            %MCPServerStatus{name: s["name"] || "", status: s["status"] || ""}
          end)
      }
    end
  end

  defmodule AssistantMessage do
    @moduledoc "An assistant response message from the CLI."
    @type t :: %__MODULE__{
            type: String.t(),
            session_id: String.t(),
            message: AssistantPayload.t(),
            parent_tool_use_id: String.t() | nil
          }
    defstruct type: "assistant",
              session_id: "",
              message: %AssistantPayload{},
              parent_tool_use_id: nil

    def from_map(map) when is_map(map) do
      msg = map["message"] || %{}
      content = Enum.map(msg["content"] || [], &parse_content/1)

      %__MODULE__{
        type: map["type"] || "assistant",
        session_id: map["session_id"] || "",
        parent_tool_use_id: map["parent_tool_use_id"],
        message: %AssistantPayload{
          id: msg["id"],
          role: msg["role"] || "assistant",
          model: msg["model"],
          content: content,
          stop_reason: msg["stop_reason"],
          stop_sequence: msg["stop_sequence"],
          usage: Usage.from_map(msg["usage"])
        }
      }
    end

    defp parse_content(%{"type" => "text"} = c),
      do: %TextContent{text: c["text"] || ""}

    defp parse_content(%{"type" => "thinking"} = c),
      do: %ThinkingContent{thinking: c["thinking"] || ""}

    defp parse_content(%{"type" => "tool_use"} = c),
      do: %ToolUseContent{id: c["id"] || "", name: c["name"] || "", input: c["input"] || %{}}

    defp parse_content(other), do: other
  end

  defmodule UserMessage do
    @moduledoc "A user message in the conversation stream."
    @type t :: %__MODULE__{
            type: String.t(),
            session_id: String.t(),
            message: UserPayload.t(),
            parent_tool_use_id: String.t() | nil
          }
    defstruct type: "user", session_id: "", message: %UserPayload{}, parent_tool_use_id: nil

    def from_map(map) when is_map(map) do
      msg = map["message"] || %{}
      content = Enum.map(msg["content"] || [], &parse_content/1)

      %__MODULE__{
        type: map["type"] || "user",
        session_id: map["session_id"] || "",
        parent_tool_use_id: map["parent_tool_use_id"],
        message: %UserPayload{
          role: msg["role"] || "user",
          content: content
        }
      }
    end

    defp parse_content(%{"type" => "text"} = c),
      do: %TextContent{text: c["text"] || ""}

    defp parse_content(%{"type" => "tool_result"} = c) do
      %ToolResultContent{
        tool_use_id: c["tool_use_id"] || "",
        content: c["content"] || "",
        is_error: c["is_error"] || false
      }
    end

    defp parse_content(other), do: other
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
            permission_denials: [String.t()] | nil
          }
    defstruct type: "result",
              subtype: "success",
              session_id: "",
              is_error: false,
              result: "",
              duration_ms: 0,
              num_turns: 0,
              usage: nil,
              permission_denials: nil

    def from_map(map) when is_map(map) do
      %__MODULE__{
        type: map["type"] || "result",
        subtype: map["subtype"] || "success",
        session_id: map["session_id"] || "",
        is_error: map["is_error"] || false,
        result: map["result"] || "",
        duration_ms: map["duration_ms"] || 0,
        num_turns: map["num_turns"] || 0,
        usage: Usage.from_map(map["usage"]),
        permission_denials: map["permission_denials"]
      }
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
            duration_ms: non_neg_integer(),
            num_turns: non_neg_integer(),
            usage: Usage.t() | nil,
            permission_denials: [String.t()] | nil
          }
    defstruct type: "result",
              subtype: "error_during_execution",
              session_id: "",
              is_error: true,
              error: "",
              duration_ms: 0,
              num_turns: 0,
              usage: nil,
              permission_denials: nil

    def from_map(map) when is_map(map) do
      %__MODULE__{
        type: map["type"] || "result",
        subtype: map["subtype"] || "error_during_execution",
        session_id: map["session_id"] || "",
        is_error: true,
        error: map["error"] || "",
        duration_ms: map["duration_ms"] || 0,
        num_turns: map["num_turns"] || 0,
        usage: Usage.from_map(map["usage"]),
        permission_denials: map["permission_denials"]
      }
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
           {:ok, env} <- fetch_env(opts) do
        {:ok,
         %__MODULE__{
           command: command,
           args: Enum.map(args, &to_string/1),
           env: Config.normalize_string_map(env),
           disabled: !!Config.read_option(opts, :disabled, false)
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
      command = Config.read_option(opts, :command)

      if is_binary(command) and String.trim(command) != "" do
        {:ok, command}
      else
        {:error, Error.new(:invalid_configuration, "MCP stdio command cannot be empty")}
      end
    end

    defp fetch_args(opts) do
      args = Config.read_option(opts, :args, [])

      if is_list(args) do
        {:ok, args}
      else
        {:error, Error.new(:invalid_configuration, "MCP stdio args must be a list")}
      end
    end

    defp fetch_env(opts) do
      env = Config.read_option(opts, :env, %{})

      if is_map(env) or is_list(env) do
        {:ok, env}
      else
        {:error, Error.new(:invalid_configuration, "MCP stdio env must be map or keyword")}
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
           {:ok, transport} <- fetch_transport(opts) do
        {:ok,
         %__MODULE__{
           url: url,
           headers: Config.normalize_string_map(headers),
           transport: transport,
           disabled: !!Config.read_option(opts, :disabled, false)
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
      url = Config.read_option(opts, :url)

      if is_binary(url) and String.trim(url) != "" do
        {:ok, url}
      else
        {:error, Error.new(:invalid_configuration, "MCP HTTP url cannot be empty")}
      end
    end

    defp fetch_headers(opts) do
      headers = Config.read_option(opts, :headers, %{})

      if is_map(headers) or is_list(headers) do
        {:ok, headers}
      else
        {:error, Error.new(:invalid_configuration, "MCP HTTP headers must be map or keyword")}
      end
    end

    defp fetch_transport(opts) do
      transport = Config.read_option(opts, :transport)

      if is_nil(transport) or is_binary(transport) do
        {:ok, transport}
      else
        {:error, Error.new(:invalid_configuration, "MCP HTTP transport must be a string")}
      end
    end
  end

  defmodule Options do
    @moduledoc "Configuration options for an Amp CLI session."
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
            stream_timeout_ms: pos_integer(),
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
              stream_timeout_ms: 300_000,
              no_ide: false,
              no_notifications: false,
              no_color: false,
              no_jetbrains: false
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
    {:ok, ErrorResultMessage.from_map(data)}
  end

  def parse_message_data(%{"type" => "result"} = data) do
    {:ok, ResultMessage.from_map(data)}
  end

  def parse_message_data(%{"type" => type} = data) when is_map_key(@message_types, type) do
    module = Map.fetch!(@message_types, type)
    {:ok, module.from_map(data)}
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
end
