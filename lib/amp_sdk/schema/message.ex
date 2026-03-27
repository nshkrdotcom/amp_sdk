defmodule AmpSdk.Schema.Message do
  @moduledoc false

  alias CliSubprocessCore.Schema.Conventions

  @spec text_content() :: Zoi.schema()
  def text_content do
    Zoi.map(
      %{
        "type" => default_trimmed_string("text"),
        "text" => default_trimmed_string("")
      },
      unrecognized_keys: :preserve
    )
  end

  @spec tool_use_content() :: Zoi.schema()
  def tool_use_content do
    Zoi.map(
      %{
        "type" => default_trimmed_string("tool_use"),
        "id" => default_trimmed_string(""),
        "name" => default_trimmed_string(""),
        "input" => default_map(%{})
      },
      unrecognized_keys: :preserve
    )
  end

  @spec tool_result_content() :: Zoi.schema()
  def tool_result_content do
    Zoi.map(
      %{
        "type" => default_trimmed_string("tool_result"),
        "tool_use_id" => default_trimmed_string(""),
        "content" => default_trimmed_string(""),
        "is_error" => Zoi.default(Zoi.optional(Zoi.nullish(Zoi.boolean())), false)
      },
      unrecognized_keys: :preserve
    )
  end

  @spec thinking_content() :: Zoi.schema()
  def thinking_content do
    Zoi.map(
      %{
        "type" => default_trimmed_string("thinking"),
        "thinking" => default_trimmed_string("")
      },
      unrecognized_keys: :preserve
    )
  end

  @spec usage() :: Zoi.schema()
  def usage do
    Zoi.map(
      %{
        "input_tokens" => default_non_neg_integer(0),
        "output_tokens" => default_non_neg_integer(0),
        "cache_creation_input_tokens" => default_non_neg_integer(0),
        "cache_read_input_tokens" => default_non_neg_integer(0),
        "service_tier" => Conventions.optional_trimmed_string()
      },
      unrecognized_keys: :preserve
    )
  end

  @spec mcp_server_status() :: Zoi.schema()
  def mcp_server_status do
    Zoi.map(
      %{
        "name" => default_trimmed_string(""),
        "status" => default_trimmed_string("")
      },
      unrecognized_keys: :preserve
    )
  end

  @spec assistant_payload() :: Zoi.schema()
  def assistant_payload do
    Zoi.map(
      %{
        "id" => Conventions.optional_trimmed_string(),
        "role" => default_trimmed_string("assistant"),
        "model" => Conventions.optional_trimmed_string(),
        "content" => default_array(),
        "stop_reason" => Conventions.optional_trimmed_string(),
        "stop_sequence" => Conventions.optional_trimmed_string(),
        "usage" => Conventions.optional_any()
      },
      unrecognized_keys: :preserve
    )
  end

  @spec user_payload() :: Zoi.schema()
  def user_payload do
    Zoi.map(
      %{
        "role" => default_trimmed_string("user"),
        "content" => default_array()
      },
      unrecognized_keys: :preserve
    )
  end

  @spec system_message() :: Zoi.schema()
  def system_message do
    Zoi.map(
      %{
        "type" => default_trimmed_string("system"),
        "subtype" => default_trimmed_string("init"),
        "session_id" => default_trimmed_string(""),
        "cwd" => default_trimmed_string(""),
        "tools" => string_list_schema(),
        "mcp_servers" => default_array()
      },
      unrecognized_keys: :preserve
    )
  end

  @spec assistant_message() :: Zoi.schema()
  def assistant_message do
    Zoi.map(
      %{
        "type" => default_trimmed_string("assistant"),
        "session_id" => default_trimmed_string(""),
        "message" => default_map(%{}),
        "parent_tool_use_id" => Conventions.optional_trimmed_string()
      },
      unrecognized_keys: :preserve
    )
  end

  @spec user_message() :: Zoi.schema()
  def user_message do
    Zoi.map(
      %{
        "type" => default_trimmed_string("user"),
        "session_id" => default_trimmed_string(""),
        "message" => default_map(%{}),
        "parent_tool_use_id" => Conventions.optional_trimmed_string()
      },
      unrecognized_keys: :preserve
    )
  end

  @spec result_message() :: Zoi.schema()
  def result_message do
    Zoi.map(
      %{
        "type" => default_trimmed_string("result"),
        "subtype" => default_trimmed_string("success"),
        "session_id" => default_trimmed_string(""),
        "is_error" => Zoi.default(Zoi.optional(Zoi.nullish(Zoi.boolean())), false),
        "result" => default_trimmed_string(""),
        "duration_ms" => default_non_neg_integer(0),
        "num_turns" => default_non_neg_integer(0),
        "usage" => Conventions.optional_any(),
        "permission_denials" => optional_string_list()
      },
      unrecognized_keys: :preserve
    )
  end

  @spec error_result_message() :: Zoi.schema()
  def error_result_message do
    Zoi.map(
      %{
        "type" => default_trimmed_string("result"),
        "subtype" => default_trimmed_string("error_during_execution"),
        "session_id" => default_trimmed_string(""),
        "is_error" => Zoi.default(Zoi.optional(Zoi.nullish(Zoi.boolean())), true),
        "error" => default_trimmed_string(""),
        "kind" => Conventions.optional_any(),
        "details" => Conventions.optional_map(),
        "exit_code" => Zoi.optional(Zoi.nullish(Zoi.integer())),
        "stderr" => Conventions.optional_trimmed_string(),
        "stderr_truncated?" => Zoi.default(Zoi.optional(Zoi.nullish(Zoi.boolean())), false),
        "duration_ms" => default_non_neg_integer(0),
        "num_turns" => default_non_neg_integer(0),
        "usage" => Conventions.optional_any(),
        "permission_denials" => optional_string_list()
      },
      unrecognized_keys: :preserve
    )
  end

  defp default_trimmed_string(default) when is_binary(default) do
    Zoi.default(Conventions.optional_trimmed_string(), default)
  end

  defp default_map(default) when is_map(default) do
    Zoi.default(Conventions.optional_map(), default)
  end

  defp default_array do
    Zoi.default(Zoi.optional(Zoi.nullish(Zoi.array(Zoi.any()))), [])
  end

  defp default_non_neg_integer(default) when is_integer(default) and default >= 0 do
    Zoi.default(
      Zoi.optional(
        Zoi.nullish(
          Zoi.integer()
          |> Zoi.min(0)
        )
      ),
      default
    )
  end

  defp string_list_schema do
    Zoi.default(
      Zoi.optional(Zoi.nullish(Zoi.array(Conventions.trimmed_string() |> Zoi.min(1)))),
      []
    )
  end

  defp optional_string_list do
    Zoi.optional(Zoi.nullish(Zoi.array(Conventions.trimmed_string() |> Zoi.min(1))))
  end
end
