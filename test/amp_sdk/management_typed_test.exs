defmodule AmpSdk.ManagementTypedTest do
  use ExUnit.Case, async: false

  alias AmpSdk.Error
  alias AmpSdk.TestSupport

  defp write_amp_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_ARGS_FILE:-}" ]; then
      printf '%s\\n' "$@" > "$AMP_TEST_ARGS_FILE"
    fi

    if [ -n "${AMP_TEST_STDIN_FILE:-}" ]; then
      cat > "$AMP_TEST_STDIN_FILE"
    fi

    if [ -n "${AMP_TEST_OUTPUT_FILE:-}" ] && [ -f "$AMP_TEST_OUTPUT_FILE" ]; then
      cat "$AMP_TEST_OUTPUT_FILE"
    else
      printf '%s' "${AMP_TEST_OUTPUT:-ok}"
    fi
    """

    TestSupport.write_executable!(dir, "amp_management_typed_stub", script)
  end

  defp with_cli_stub(fun, extra_env) when is_function(fun, 2) do
    dir = TestSupport.tmp_dir!("amp_management_typed")
    args_file = Path.join(dir, "args.txt")
    stdin_file = Path.join(dir, "stdin.txt")
    output_file = Path.join(dir, "output.txt")
    amp_path = write_amp_stub!(dir)

    output = Map.get(extra_env, "AMP_TEST_OUTPUT", "ok")
    File.write!(output_file, output)

    extra_env = Map.delete(extra_env, "AMP_TEST_OUTPUT")

    try do
      TestSupport.with_env(
        Map.merge(
          %{
            "AMP_CLI_PATH" => amp_path,
            "AMP_TEST_ARGS_FILE" => args_file,
            "AMP_TEST_STDIN_FILE" => stdin_file,
            "AMP_TEST_OUTPUT_FILE" => output_file
          },
          extra_env
        ),
        fn ->
          fun.(args_file, stdin_file)
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  defp read_args!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
  end

  test "threads_list returns typed thread summaries" do
    output = """
    Title                                         Last Updated  Visibility  Messages  Thread ID
    ────────────────────────────────────────────  ────────────  ──────────  ────────  ──────────────────────────────────────
    OTP refactor tracking                         2m ago        Workspace          4  T-01234567-89ab-cdef-0123-456789abcdef
    Untitled                                      1h ago        Private            1  T-11111111-2222-3333-4444-555555555555
    """

    with_cli_stub(
      fn args_file, _stdin_file ->
        assert {:ok, threads} = AmpSdk.threads_list()
        assert length(threads) == 2

        assert [%AmpSdk.Types.ThreadSummary{} = first, %AmpSdk.Types.ThreadSummary{} = second] =
                 threads

        assert first.id == "T-01234567-89ab-cdef-0123-456789abcdef"
        assert first.title == "OTP refactor tracking"
        assert first.last_updated == "2m ago"
        assert first.visibility == :workspace
        assert first.messages == 4
        refute Map.has_key?(first, :raw)

        assert second.id == "T-11111111-2222-3333-4444-555555555555"
        assert second.visibility == :private
        refute Map.has_key?(second, :raw)

        assert read_args!(args_file) == ["threads", "list"]
      end,
      %{"AMP_TEST_OUTPUT" => output}
    )
  end

  test "threads_list returns parse_error for malformed table rows" do
    output = """
    Title                                         Last Updated  Visibility  Messages  Thread ID
    ────────────────────────────────────────────  ────────────  ──────────  ────────  ──────────────────────────────────────
    malformed row with no expected columns
    """

    with_cli_stub(
      fn _args_file, _stdin_file ->
        assert {:error, %Error{kind: :parse_error} = error} = AmpSdk.threads_list()
        assert error.message =~ "Failed to parse thread list output"
      end,
      %{"AMP_TEST_OUTPUT" => output}
    )
  end

  test "permissions_list returns typed permission rules using JSON output" do
    output = """
    [{"tool":"Read","action":"allow"},{"tool":"Bash","action":"ask","context":"workspace"}]
    """

    with_cli_stub(
      fn args_file, _stdin_file ->
        assert {:ok, rules} = AmpSdk.permissions_list()
        assert length(rules) == 2

        assert [%AmpSdk.Types.PermissionRule{} = first, %AmpSdk.Types.PermissionRule{} = second] =
                 rules

        assert first.tool == "Read"
        assert first.action == "allow"
        refute Map.has_key?(first, :raw)
        assert second.tool == "Bash"
        assert second.action == "ask"
        assert second.context == "workspace"
        refute Map.has_key?(second, :raw)

        assert read_args!(args_file) == ["permissions", "list", "--json"]
      end,
      %{"AMP_TEST_OUTPUT" => output}
    )
  end

  test "permissions_list returns parse_error when json cannot be decoded" do
    with_cli_stub(
      fn _args_file, _stdin_file ->
        assert {:error, %Error{kind: :parse_error} = error} = AmpSdk.permissions_list()
        assert error.message =~ "Failed to decode permissions list JSON"
      end,
      %{"AMP_TEST_OUTPUT" => "not-json"}
    )
  end

  test "mcp_list returns typed mcp servers using JSON output" do
    output = """
    [{"name":"filesystem","type":"command","source":"workspace","command":"npx","args":["-y","@modelcontextprotocol/server-filesystem"]},{"name":"remote","type":"url","source":"global","url":"https://example.com/mcp"}]
    """

    with_cli_stub(
      fn args_file, _stdin_file ->
        assert {:ok, servers} = AmpSdk.mcp_list()
        assert length(servers) == 2

        assert [%AmpSdk.Types.MCPServer{} = first, %AmpSdk.Types.MCPServer{} = second] = servers

        assert first.name == "filesystem"
        assert first.type == "command"
        assert first.source == "workspace"
        assert first.command == "npx"
        assert first.args == ["-y", "@modelcontextprotocol/server-filesystem"]
        refute Map.has_key?(first, :raw)

        assert second.name == "remote"
        assert second.type == "url"
        assert second.url == "https://example.com/mcp"
        refute Map.has_key?(second, :raw)

        assert read_args!(args_file) == ["mcp", "list", "--json"]
      end,
      %{"AMP_TEST_OUTPUT" => output}
    )
  end

  test "mcp_list returns parse_error when json cannot be decoded" do
    with_cli_stub(
      fn _args_file, _stdin_file ->
        assert {:error, %Error{kind: :parse_error} = error} = AmpSdk.mcp_list()
        assert error.message =~ "Failed to decode MCP list JSON"
      end,
      %{"AMP_TEST_OUTPUT" => "not-json"}
    )
  end
end
