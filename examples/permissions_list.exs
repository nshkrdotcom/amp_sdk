# List current permission rules
# Run with: mix run examples/permissions_list.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== Permissions ===\n")

case AmpSdk.permissions_list(Support.command_opts()) do
  {:ok, rules} ->
    IO.puts("Found #{length(rules)} rule(s)\n")

    Enum.each(rules, fn rule ->
      IO.puts("#{rule.action} #{rule.tool}")
    end)

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
