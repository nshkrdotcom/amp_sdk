# Example using permissions to control tool access
#
# Run with: mix run examples/with_permissions.exs

alias AmpSdk.Types.Options

IO.puts("=== AmpSdk With Permissions ===\n")

permissions = [
  AmpSdk.create_permission("Bash", "allow"),
  AmpSdk.create_permission("Read", "allow"),
  AmpSdk.create_permission("edit_file", "reject"),
  AmpSdk.create_permission("create_file", "reject")
]

options = %Options{
  permissions: permissions,
  dangerously_allow_all: true,
  mode: "smart"
}

case AmpSdk.run(
       "List the files in the current directory using ls. Reply with only the output.",
       options
     ) do
  {:ok, result} ->
    IO.puts("Result:\n#{result}")

  {:error, %AmpSdk.Error{kind: kind, message: message}} ->
    IO.puts("Error [#{kind}]: #{message}")
end

System.halt(0)
