defmodule AmpSdk.ThinkingTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Types
  alias AmpSdk.Types.{AssistantMessage, TextContent, ThinkingContent}

  describe "ThinkingContent" do
    test "parses thinking content in assistant message" do
      json =
        Jason.encode!(%{
          type: "assistant",
          session_id: "T-123",
          message: %{
            role: "assistant",
            content: [
              %{type: "thinking", thinking: "Let me think..."},
              %{type: "text", text: "The answer is 4"}
            ],
            stop_reason: "end_turn",
            usage: %{input_tokens: 10, output_tokens: 13}
          }
        })

      assert {:ok, %AssistantMessage{} = msg} = Types.parse_stream_message(json)

      assert [
               %ThinkingContent{thinking: "Let me think..."},
               %TextContent{text: "The answer is 4"}
             ] = msg.message.content
    end

    test "ThinkingContent struct defaults" do
      tc = %ThinkingContent{}
      assert tc.type == "thinking"
      assert tc.thinking == ""
    end
  end

  describe "Options.thinking" do
    test "defaults to false" do
      opts = %AmpSdk.Types.Options{}
      assert opts.thinking == false
    end

    test "can be set to true" do
      opts = %AmpSdk.Types.Options{thinking: true}
      assert opts.thinking == true
    end
  end

  describe "build_args with thinking" do
    test "uses --stream-json-thinking when thinking: true" do
      args = AmpSdk.Stream.build_args(%AmpSdk.Types.Options{thinking: true})
      assert "--stream-json-thinking" in args
      refute "--stream-json" in args
    end

    test "uses --stream-json when thinking: false" do
      args = AmpSdk.Stream.build_args(%AmpSdk.Types.Options{thinking: false})
      assert "--stream-json" in args
      refute "--stream-json-thinking" in args
    end
  end
end
