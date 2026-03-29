# Thread management example
#
# Run with: mix run examples/threads.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias AmpSdk.Types.Options
alias Examples.Support

Support.init!()

IO.puts("=== AmpSdk Threads ===\n")

thread_id =
  AmpSdk.execute(
    "Reply with only: thread markdown sample",
    %Options{
      dangerously_allow_all: true,
      visibility: "private"
    }
    |> Support.with_execution_surface()
  )
  |> Enum.reduce(nil, fn message, acc ->
    case AmpSdk.Types.session_id(message) do
      nil -> acc
      id -> id
    end
  end)

case thread_id do
  nil ->
    IO.puts("Failed to create thread from execution stream.")

  thread_id ->
    IO.puts("Created thread: #{thread_id}")

    case Support.invoke(["threads", "markdown", thread_id]) do
      {:ok, markdown} ->
        IO.puts("\nThread markdown:\n#{markdown}")

      {:error, %AmpSdk.Error{kind: kind, message: message}} ->
        IO.puts("Failed to get markdown [#{kind}]: #{message}")
    end
end

System.halt(0)
