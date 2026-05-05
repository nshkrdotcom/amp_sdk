defmodule AmpSdk.GovernedLaunchTest do
  use ExUnit.Case, async: false

  alias AmpSdk.{CLIInvoke, Command, Error, GovernedLaunch, MCP, Permissions, TestSupport}
  alias AmpSdk.Runtime.CLI
  alias AmpSdk.Types.{Options, Permission}
  alias CliSubprocessCore.{CommandSpec, GovernedAuthority}

  defp authority(command, opts) do
    GovernedAuthority.fetch!(%{
      authority_ref: "authority:amp:test",
      credential_lease_ref: Keyword.get(opts, :credential_lease_ref, "lease:amp:test"),
      connector_instance_ref:
        Keyword.get(opts, :connector_instance_ref, "connector-instance:amp:test"),
      connector_binding_ref:
        Keyword.get(opts, :connector_binding_ref, "connector-binding:amp:test"),
      provider_account_ref: Keyword.get(opts, :provider_account_ref, "provider-account:amp:test"),
      native_auth_assertion_ref:
        Keyword.get(opts, :native_auth_assertion_ref, "native-auth-assertion:amp:test"),
      target_ref: Keyword.get(opts, :target_ref, "target:amp:test"),
      operation_policy_ref: Keyword.get(opts, :operation_policy_ref, "operation-policy:amp:test"),
      materialized_command: command,
      materialized_cwd: Keyword.get(opts, :cwd),
      materialized_env: Keyword.get(opts, :env, %{}),
      clear_env?: true,
      command_ref: Keyword.get(opts, :command_ref, "command:amp:test"),
      redaction_ref: Keyword.get(opts, :redaction_ref, "redaction:amp:test")
    })
  end

  defp write_token_stub!(dir, name \\ "amp") do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%s\\n' "$AMP_AUTHORITY_TOKEN"
    """

    TestSupport.write_executable!(dir, name, script)
  end

  defp write_session_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail
    sleep 60
    """

    TestSupport.write_executable!(dir, "amp", script)
  end

  test "governed Command.run/2 uses authority command and env instead of CLI discovery" do
    dir = TestSupport.tmp_dir!("amp_governed_command")
    stub_path = write_token_stub!(dir)

    authority =
      authority(stub_path,
        cwd: dir,
        env: %{"AMP_AUTHORITY_TOKEN" => "lease-token"}
      )

    try do
      TestSupport.with_env(
        %{"AMP_CLI_PATH" => "/nonexistent/ambient/amp", "AMP_AUTHORITY_TOKEN" => "ambient"},
        fn ->
          assert {:ok, "lease-token"} =
                   Command.run(["threads", "list"],
                     governed_authority: authority,
                     trim_output: true
                   )
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "governed sessions use only authority command, cwd, and env" do
    dir = TestSupport.tmp_dir!("amp_governed_session")
    stub_path = write_session_stub!(dir)
    session_ref = make_ref()

    authority =
      authority(stub_path,
        cwd: dir,
        env: %{"AMP_AUTHORITY_TOKEN" => "session-token"}
      )

    try do
      TestSupport.with_env(
        %{"AMP_CLI_PATH" => "/nonexistent/ambient/amp", "AMP_AUTHORITY_TOKEN" => "ambient"},
        fn ->
          assert {:ok, session, %{info: info, temp_dir: temp_dir}} =
                   CLI.start_session(
                     input: "hello governed amp",
                     options: %Options{governed_authority: authority},
                     subscriber: {self(), session_ref}
                   )

          assert info.invocation.command == stub_path
          assert info.invocation.cwd == dir
          assert info.invocation.env == %{"AMP_AUTHORITY_TOKEN" => "session-token"}
          assert temp_dir == nil

          monitor_ref = Process.monitor(session)
          assert :ok = CLI.close(session)
          assert_receive {:DOWN, ^monitor_ref, :process, ^session, :normal}, 2_000
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "invalid governed authority fails closed without CLI discovery fallback" do
    assert {:error, %ArgumentError{} = error} =
             CLI.start_session(
               input: "hello governed amp",
               options: %Options{governed_authority: %{authority_ref: "incomplete"}}
             )

    assert Exception.message(error) =~ "governed Amp launch rejected"
  end

  test "governed options reject env, cwd, settings, permissions, MCP, and model env smuggling" do
    base = authority("/bin/amp", env: %{"AMP_AUTHORITY_TOKEN" => "lease-token"})

    rejected = [
      {:env, %{"AMP_API_KEY" => "ambient"}},
      {:cwd, "/tmp/ambient"},
      {:settings_file, "/tmp/settings.json"},
      {:permissions, [Permission.new!("Bash", "allow")]},
      {:skills, "/tmp/skills"},
      {:mcp_config, %{"server" => %{"command" => "npx"}}},
      {:execution_surface, [surface_kind: :local]},
      {:dangerously_allow_all, true},
      {:model_payload, %{env_overrides: %{"AMP_API_KEY" => "ambient"}}}
    ]

    for {field, value} <- rejected do
      options = struct!(Options, [{:governed_authority, base}, {field, value}])

      assert_raise ArgumentError, fn ->
        Options.validate!(options)
      end
    end
  end

  test "governed command options reject command specs, env, cwd, and execution overrides" do
    base = authority("/bin/amp", env: %{"AMP_AUTHORITY_TOKEN" => "lease-token"})

    assert {:error, %Error{kind: :invalid_configuration}} =
             Command.run(%CommandSpec{program: "/bin/amp"}, ["threads", "list"],
               governed_authority: base
             )

    for opts <- [
          [governed_authority: base, env: %{"AMP_API_KEY" => "ambient"}],
          [governed_authority: base, cd: "/tmp/ambient"],
          [governed_authority: base, execution_surface: [surface_kind: :local]],
          [
            governed_authority: base,
            model_payload: %{env_overrides: %{"AMP_API_KEY" => "ambient"}}
          ]
        ] do
      assert {:error, %Error{kind: :invalid_configuration}} =
               Command.run(["threads", "list"], opts)
    end
  end

  test "CLIInvoke management commands can use governed authority for non-auth management" do
    dir = TestSupport.tmp_dir!("amp_governed_cli_invoke")
    stub_path = write_token_stub!(dir)
    authority = authority(stub_path, env: %{"AMP_AUTHORITY_TOKEN" => "management-token"})

    try do
      assert {:ok, "management-token"} =
               CLIInvoke.invoke(["threads", "list"], governed_authority: authority)
    after
      File.rm_rf(dir)
    end
  end

  test "governed mode rejects native MCP OAuth and permissions config state" do
    base = authority("/bin/amp", env: %{"AMP_AUTHORITY_TOKEN" => "lease-token"})

    assert {:error, %Error{kind: :invalid_configuration}} =
             MCP.oauth_login("oauth-server",
               governed_authority: base,
               server_url: "https://example.com/mcp",
               client_id: "client-id",
               client_secret: "client-secret"
             )

    assert {:error, %Error{kind: :invalid_configuration}} =
             MCP.oauth_status("oauth-server", governed_authority: base)

    assert {:error, %Error{kind: :invalid_configuration}} =
             Permissions.add("Bash", "allow", governed_authority: base)
  end

  test "standalone explicit command compatibility is preserved" do
    dir = TestSupport.tmp_dir!("amp_standalone_command")
    stub_path = write_token_stub!(dir)

    try do
      assert {:ok, "standalone-token"} =
               Command.run(%CommandSpec{program: stub_path}, ["threads", "list"],
                 env: %{"AMP_AUTHORITY_TOKEN" => "standalone-token"},
                 trim_output: true
               )
    after
      File.rm_rf(dir)
    end
  end

  test "governed launch validator accepts authority-only options" do
    base = authority("/bin/amp", env: %{"AMP_AUTHORITY_TOKEN" => "lease-token"})

    assert :ok = GovernedLaunch.validate_options(%Options{governed_authority: base})
  end

  test "keeps two native auth roots distinct and redacts projected launch state" do
    root_a =
      authority("/authority/bin/amp",
        provider_account_ref: "provider-account:amp:a",
        native_auth_assertion_ref: "native-auth-assertion:amp:a",
        auth_root: "/authority/amp/a"
      )

    root_b =
      authority("/authority/bin/amp",
        provider_account_ref: "provider-account:amp:b",
        native_auth_assertion_ref: "native-auth-assertion:amp:b",
        auth_root: "/authority/amp/b"
      )

    assert root_a.provider_account_ref == "provider-account:amp:a"
    assert root_b.provider_account_ref == "provider-account:amp:b"
    assert root_a.native_auth_assertion_ref != root_b.native_auth_assertion_ref

    projection = GovernedAuthority.redacted(root_a)

    assert projection.provider_account_ref == "provider-account:amp:a"
    assert projection.native_auth_assertion_ref == "native-auth-assertion:amp:a"
    assert projection.command != "/authority/bin/amp"
    refute String.contains?(inspect(projection), "/authority/bin/amp")
  end
end
