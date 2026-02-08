# List current permission rules
# Run with: mix run examples/permissions_list.exs

IO.puts("=== Permissions ===\n")

case AmpSdk.permissions_list() do
  {:ok, rules} ->
    IO.puts("Found #{length(rules)} rule(s)\n")

    Enum.each(rules, fn rule ->
      IO.puts("#{rule.action} #{rule.tool}")
    end)

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
