# Multi-turn conversation using create_user_message/1
# Run with: mix run examples/create_user_message.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias AmpSdk.Types.Options
alias Examples.Support

Support.init!()

IO.puts("=== Create User Message ===\n")

messages = [
  AmpSdk.create_user_message("Remember the word 'pineapple'. Reply with: OK"),
  AmpSdk.create_user_message("What word did I ask you to remember? Reply with only the word.")
]

AmpSdk.execute(
  messages,
  %Options{dangerously_allow_all: true}
  |> Support.with_execution_surface()
)
|> Enum.each(fn
  %AmpSdk.Types.AssistantMessage{message: %{content: content}} ->
    Enum.each(content, fn
      %AmpSdk.Types.TextContent{text: t} -> IO.puts("[assistant] #{t}")
      _ -> :ok
    end)

  %AmpSdk.Types.ResultMessage{result: r} ->
    IO.puts("[result] #{r}")

  _ ->
    :ok
end)

System.halt(0)
