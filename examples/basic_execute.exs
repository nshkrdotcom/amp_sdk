# Basic execution example - sends a prompt and collects the response
#
# Run with: mix run examples/basic_execute.exs

alias AmpSdk.Types.Options

IO.puts("=== AmpSdk Basic Execute ===\n")

prompt = "Respond with only the text: Hello from Elixir!"

IO.puts("Prompt: #{prompt}")
IO.puts("Streaming response...\n")

AmpSdk.execute(prompt, %Options{dangerously_allow_all: true})
|> Enum.each(fn msg ->
  case msg do
    %AmpSdk.Types.SystemMessage{session_id: sid, tools: tools} ->
      IO.puts("[system] session=#{sid} tools=#{length(tools)}")

    %AmpSdk.Types.AssistantMessage{message: %{content: content}} ->
      Enum.each(content, fn
        %AmpSdk.Types.TextContent{text: text} ->
          IO.puts("[assistant] #{text}")

        %AmpSdk.Types.ToolUseContent{name: name} ->
          IO.puts("[tool_use] #{name}")

        _ ->
          :ok
      end)

    %AmpSdk.Types.UserMessage{} ->
      IO.puts("[user] (tool result)")

    %AmpSdk.Types.ResultMessage{result: result, duration_ms: ms, num_turns: turns} ->
      IO.puts("\n[result] #{result}")
      IO.puts("[stats] #{ms}ms, #{turns} turn(s)")

    %AmpSdk.Types.ErrorResultMessage{error: error} ->
      IO.puts("\n[error] #{error}")

    other ->
      IO.puts("[unknown] #{inspect(other)}")
  end
end)

System.halt(0)
