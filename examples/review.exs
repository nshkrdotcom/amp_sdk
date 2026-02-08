# Code review example
# Run with: mix run examples/review.exs

IO.puts("=== Code Review ===\n")

case AmpSdk.review(files: ["lib/amp_sdk.ex"], summary_only: true, dangerously_allow_all: true) do
  {:ok, output} ->
    result = String.trim(output)

    if result == "",
      do: IO.puts("(No review output; likely no diff to review.)"),
      else: IO.puts(result)

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
