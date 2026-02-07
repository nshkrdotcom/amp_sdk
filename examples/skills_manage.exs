# Skill lifecycle: add, info, remove
# Run with: mix run examples/skills_manage.exs

IO.puts("=== Skills Manage ===\n")

# Create a minimal skill directory with SKILL.md (required filename)
skill_dir = Path.join(System.tmp_dir!(), "amp-sdk-test-skill")
File.mkdir_p!(skill_dir)

File.write!(Path.join(skill_dir, "SKILL.md"), """
---
name: amp-sdk-test-skill
description: A test skill created by the Amp SDK example
---

When invoked, reply with: This is a test skill.
""")

IO.puts("Created skill dir: #{skill_dir}")

# Add
IO.puts("\nAdding skill:")

case AmpSdk.skills_add(skill_dir) do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, err} -> IO.puts("  Error: #{inspect(err)}")
end

# Info
IO.puts("\nSkill info:")

case AmpSdk.skills_info("amp-sdk-test-skill") do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, err} -> IO.puts("  Error: #{inspect(err)}")
end

# Remove
IO.puts("\nRemoving skill:")

case AmpSdk.skills_remove("amp-sdk-test-skill") do
  {:ok, output} -> IO.puts("  #{String.trim(output)}")
  {:error, err} -> IO.puts("  Error: #{inspect(err)}")
end

# Cleanup
File.rm_rf!(skill_dir)

System.halt(0)
