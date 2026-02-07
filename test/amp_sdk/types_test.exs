defmodule AmpSdk.TypesTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Error
  alias AmpSdk.Types

  alias AmpSdk.Types.{
    AssistantMessage,
    AssistantPayload,
    ErrorResultMessage,
    Options,
    Permission,
    ResultMessage,
    SystemMessage,
    TextContent,
    ToolResultContent,
    ToolUseContent,
    Usage,
    UserInputMessage,
    UserMessage,
    UserPayload
  }

  describe "parse_stream_message/1" do
    test "parses system init message" do
      json =
        Jason.encode!(%{
          type: "system",
          subtype: "init",
          session_id: "T-123",
          cwd: "/tmp",
          tools: ["Bash", "Read"],
          mcp_servers: [%{name: "fs", status: "connected"}]
        })

      assert {:ok, %SystemMessage{} = msg} = Types.parse_stream_message(json)
      assert msg.session_id == "T-123"
      assert msg.cwd == "/tmp"
      assert msg.tools == ["Bash", "Read"]
      assert [%{name: "fs", status: "connected"}] = msg.mcp_servers
    end

    test "parses assistant message with text content" do
      json =
        Jason.encode!(%{
          type: "assistant",
          session_id: "T-123",
          message: %{
            role: "assistant",
            content: [%{type: "text", text: "hello"}],
            stop_reason: "end_turn",
            usage: %{input_tokens: 10, output_tokens: 5}
          }
        })

      assert {:ok, %AssistantMessage{} = msg} = Types.parse_stream_message(json)
      assert msg.session_id == "T-123"
      assert %AssistantPayload{} = msg.message
      assert [%TextContent{text: "hello"}] = msg.message.content
      assert msg.message.stop_reason == "end_turn"
      assert msg.message.usage.input_tokens == 10
    end

    test "parses assistant message with tool use content" do
      json =
        Jason.encode!(%{
          type: "assistant",
          session_id: "T-123",
          message: %{
            role: "assistant",
            content: [
              %{type: "tool_use", id: "tu_1", name: "Bash", input: %{command: "ls"}}
            ]
          }
        })

      assert {:ok, %AssistantMessage{} = msg} = Types.parse_stream_message(json)
      assert [%ToolUseContent{name: "Bash", input: %{"command" => "ls"}}] = msg.message.content
    end

    test "parses user message with tool result" do
      json =
        Jason.encode!(%{
          type: "user",
          session_id: "T-123",
          message: %{
            role: "user",
            content: [
              %{type: "tool_result", tool_use_id: "tu_1", content: "file.txt", is_error: false}
            ]
          }
        })

      assert {:ok, %UserMessage{} = msg} = Types.parse_stream_message(json)
      assert %UserPayload{} = msg.message
      assert [%ToolResultContent{tool_use_id: "tu_1"}] = msg.message.content
    end

    test "parses success result message" do
      json =
        Jason.encode!(%{
          type: "result",
          subtype: "success",
          session_id: "T-123",
          is_error: false,
          result: "done",
          duration_ms: 1500,
          num_turns: 3
        })

      assert {:ok, %ResultMessage{} = msg} = Types.parse_stream_message(json)
      assert msg.result == "done"
      assert msg.duration_ms == 1500
      assert msg.num_turns == 3
      assert msg.is_error == false
    end

    test "parses error result message" do
      json =
        Jason.encode!(%{
          type: "result",
          subtype: "error_during_execution",
          session_id: "T-123",
          is_error: true,
          error: "something failed",
          duration_ms: 500,
          num_turns: 1
        })

      assert {:ok, %ErrorResultMessage{} = msg} = Types.parse_stream_message(json)
      assert msg.error == "something failed"
      assert msg.is_error == true
    end

    test "returns error for unknown type" do
      json = Jason.encode!(%{type: "unknown_thing"})

      assert {:error, %Error{kind: :invalid_message, cause: "unknown_thing"}} =
               Types.parse_stream_message(json)
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Types.parse_stream_message("{broken json")
    end

    test "returns error for missing type field" do
      json = Jason.encode!(%{foo: "bar"})

      assert {:error, %Error{kind: :invalid_message, cause: :missing_type_field}} =
               Types.parse_stream_message(json)
    end
  end

  describe "final_message?/1" do
    test "ResultMessage is final" do
      assert Types.final_message?(%ResultMessage{})
    end

    test "ErrorResultMessage is final" do
      assert Types.final_message?(%ErrorResultMessage{})
    end

    test "SystemMessage is not final" do
      refute Types.final_message?(%SystemMessage{})
    end

    test "AssistantMessage is not final" do
      refute Types.final_message?(%AssistantMessage{})
    end
  end

  describe "create_user_message/1" do
    test "creates user input message" do
      msg = Types.create_user_message("hello")
      assert %UserInputMessage{type: "user"} = msg
      assert msg.message.role == "user"
      assert [%TextContent{text: "hello"}] = msg.message.content
    end
  end

  describe "Usage.from_map/1" do
    test "handles nil" do
      assert Usage.from_map(nil) == nil
    end

    test "coerces nil values to 0" do
      usage = Usage.from_map(%{"input_tokens" => nil, "output_tokens" => nil})
      assert usage.input_tokens == 0
      assert usage.output_tokens == 0
    end

    test "parses all fields" do
      usage =
        Usage.from_map(%{
          "input_tokens" => 100,
          "output_tokens" => 50,
          "cache_creation_input_tokens" => 10,
          "cache_read_input_tokens" => 20,
          "service_tier" => "default"
        })

      assert usage.input_tokens == 100
      assert usage.output_tokens == 50
      assert usage.service_tier == "default"
    end
  end

  describe "Permission.new!/3" do
    test "creates basic permission" do
      perm = Permission.new!("Bash", "allow")
      assert perm.tool == "Bash"
      assert perm.action == "allow"
    end

    test "creates permission with matches" do
      perm = Permission.new!("Read", "ask", matches: %{"path" => "/secret/*"})
      assert perm.matches == %{"path" => "/secret/*"}
    end

    test "creates delegate permission" do
      perm = Permission.new!("Bash", "delegate", to: "bash -c")
      assert perm.action == "delegate"
      assert perm.to == "bash -c"
    end

    test "raises on delegate without to" do
      assert_raise Error, ~r/delegate/, fn ->
        Permission.new!("Bash", "delegate")
      end
    end

    test "raises on to without delegate" do
      assert_raise Error, ~r/to/, fn ->
        Permission.new!("Bash", "allow", to: "something")
      end
    end
  end

  describe "Options struct" do
    test "defaults" do
      opts = %Options{}
      assert opts.mode == "smart"
      assert opts.visibility == "workspace"
      assert opts.dangerously_allow_all == false
      assert opts.env == %{}
      assert opts.stream_timeout_ms == 300_000
    end
  end
end
