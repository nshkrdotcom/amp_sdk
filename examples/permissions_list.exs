# List current permission rules
# Run with: mix run examples/permissions_list.exs

IO.puts("=== Permissions ===\n")

case AmpSdk.permissions_list() do
  {:ok, output} -> IO.puts(output)
  {:error, err} -> IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
