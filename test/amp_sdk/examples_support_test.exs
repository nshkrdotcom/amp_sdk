defmodule AmpSdk.ExamplesSupportTest do
  use ExUnit.Case, async: true

  alias AmpSdk.ExamplesSupport
  alias AmpSdk.Types.Options
  alias CliSubprocessCore.ExecutionSurface

  test "parse_argv/1 keeps local defaults when ssh flags are absent" do
    assert {:ok, context} = ExamplesSupport.parse_argv(["--", "threads"])

    assert context.argv == ["threads"]
    assert context.execution_surface == nil
  end

  test "parse_argv/1 builds ssh execution_surface from shared flags" do
    assert {:ok, context} =
             ExamplesSupport.parse_argv([
               "--ssh-host",
               "builder@example.internal",
               "--ssh-port",
               "2222",
               "--ssh-identity-file",
               "./tmp/id_ed25519"
             ])

    assert %ExecutionSurface{} = context.execution_surface
    assert context.execution_surface.surface_kind == :ssh_exec
    assert context.execution_surface.transport_options[:destination] == "example.internal"
    assert context.execution_surface.transport_options[:ssh_user] == "builder"
    assert context.execution_surface.transport_options[:port] == 2222
    assert context.execution_surface.transport_options[:identity_file] =~ "/tmp/id_ed25519"
  end

  test "parse_argv/1 rejects orphan ssh flags without --ssh-host" do
    assert {:error, message} = ExamplesSupport.parse_argv(["--ssh-port", "2222"])
    assert message =~ "require --ssh-host"
  end

  test "with_execution_surface/1 injects the parsed surface into options structs" do
    assert {:ok, context} = ExamplesSupport.parse_argv(["--ssh-host", "example.internal"])

    Process.put({ExamplesSupport, :ssh_context}, context)

    opts =
      %Options{dangerously_allow_all: true}
      |> ExamplesSupport.with_execution_surface()

    assert opts.execution_surface.surface_kind == :ssh_exec
    assert opts.execution_surface.transport_options[:destination] == "example.internal"
  after
    Process.delete({ExamplesSupport, :ssh_context})
  end
end
