# Execute with thinking blocks visible
# Run with: mix run examples/thinking.exs

alias AmpSdk.Types.{Options, ThinkingContent, TextContent}

IO.puts("=== Thinking Mode ===\n")

AmpSdk.execute("What is 7 * 8? Reply only the number.", %Options{
  thinking: true,
  dangerously_allow_all: true
})
|> Enum.each(fn
  %AmpSdk.Types.AssistantMessage{message: %{content: content}} ->
    Enum.each(content, fn
      %ThinkingContent{thinking: t} -> IO.puts("[thinking] #{t}")
      %TextContent{text: t} -> IO.puts("[text] #{t}")
      _ -> :ok
    end)

  %AmpSdk.Types.ResultMessage{result: r, duration_ms: ms} ->
    IO.puts("[result] #{r} (#{ms}ms)")

  _ ->
    :ok
end)

System.halt(0)
