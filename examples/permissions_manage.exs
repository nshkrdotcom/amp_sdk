# Test and add permissions
# Run with: mix run examples/permissions_manage.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== Permissions Manage ===\n")

# Test whether a tool is allowed (exit code 1 means action is "ask")
IO.puts("Testing Bash tool:")

case AmpSdk.permissions_test("Bash", Support.command_opts()) do
  {:ok, output} ->
    IO.puts("  #{String.trim(output)}")

  {:error, err} ->
    details = Map.get(err, :details, "") |> to_string() |> String.trim()
    if details != "", do: IO.puts("  #{details}"), else: IO.puts("  Error: #{inspect(err)}")
end

# Add a permission rule
IO.puts("\nAdding Read allow rule:")

already_allowed? =
  case AmpSdk.permissions_list(Support.command_opts()) do
    {:ok, rules} ->
      Enum.any?(rules, &(&1.action == "allow" and &1.tool == "Read"))

    {:error, _err} ->
      false
  end

if already_allowed? do
  IO.puts("  Rule already exists (skipping add).")
else
  case AmpSdk.permissions_add("Read", "allow", Support.command_opts()) do
    {:ok, output} ->
      result = String.trim(output)
      if result == "", do: IO.puts("  OK"), else: IO.puts("  #{result}")

    {:error, err} ->
      IO.puts("  Error: #{inspect(err)}")
      System.halt(1)
  end
end

System.halt(0)
