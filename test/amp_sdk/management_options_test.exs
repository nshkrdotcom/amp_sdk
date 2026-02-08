defmodule AmpSdk.ManagementOptionsTest do
  use ExUnit.Case, async: false

  alias AmpSdk.TestSupport

  defp write_amp_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${AMP_TEST_ARGS_FILE:-}" ]; then
      printf '%s\n' "$@" > "$AMP_TEST_ARGS_FILE"
    fi

    if [ -n "${AMP_TEST_STDIN_FILE:-}" ]; then
      cat > "$AMP_TEST_STDIN_FILE"
    fi

    exit_code="${AMP_TEST_EXIT_CODE:-0}"
    if [ "$exit_code" != "0" ]; then
      echo "${AMP_TEST_ERROR_TEXT:-command failed}" >&2
      exit "$exit_code"
    fi

    echo "${AMP_TEST_OUTPUT:-ok}"
    """

    TestSupport.write_executable!(dir, "amp_options_stub", script)
  end

  defp with_cli_stub(fun, extra_env \\ %{}) when is_function(fun, 2) do
    dir = TestSupport.tmp_dir!("amp_management_opts")
    args_file = Path.join(dir, "args.txt")
    stdin_file = Path.join(dir, "stdin.txt")
    amp_path = write_amp_stub!(dir)

    try do
      TestSupport.with_env(
        Map.merge(
          %{
            "AMP_CLI_PATH" => amp_path,
            "AMP_TEST_ARGS_FILE" => args_file,
            "AMP_TEST_STDIN_FILE" => stdin_file,
            "AMP_TEST_OUTPUT" => "ok"
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

  test "tools_use expands list values as repeated flags" do
    with_cli_stub(fn args_file, _stdin_file ->
      assert {:ok, "ok"} =
               AmpSdk.tools_use("Read",
                 only: "content",
                 args: [path: "/tmp/file.txt", read_range: [1, 5]]
               )

      assert read_args!(args_file) == [
               "tools",
               "use",
               "Read",
               "--only",
               "content",
               "--path",
               "/tmp/file.txt",
               "--read_range",
               "1",
               "--read_range",
               "5"
             ]
    end)
  end

  test "tasks_import forwards dry-run, repo, and force flags" do
    with_cli_stub(fn args_file, _stdin_file ->
      assert {:ok, "ok"} =
               AmpSdk.tasks_import("/tmp/tasks.json",
                 repo: "https://github.com/org/repo",
                 dry_run: true,
                 force: true
               )

      assert read_args!(args_file) == [
               "tasks",
               "import",
               "/tmp/tasks.json",
               "--repo",
               "https://github.com/org/repo",
               "--dry-run",
               "--force"
             ]
    end)
  end

  test "threads_handoff forwards goal, print, and stdin input" do
    with_cli_stub(fn args_file, stdin_file ->
      assert {:ok, "ok"} =
               AmpSdk.threads_handoff("T-123",
                 goal: "Continue the auth work",
                 print: true,
                 input: "hello from stdin\n"
               )

      assert read_args!(args_file) == [
               "threads",
               "handoff",
               "T-123",
               "--goal",
               "Continue the auth work",
               "--print"
             ]

      assert File.read!(stdin_file) == "hello from stdin\n"
    end)
  end

  test "threads_replay forwards replay options" do
    with_cli_stub(fn args_file, _stdin_file ->
      assert {:ok, "ok"} =
               AmpSdk.threads_replay("T-123",
                 wpm: 200,
                 no_typing: true,
                 message_delay: 10,
                 tool_progress_delay: 20,
                 exit_delay: 0,
                 no_indicator: true
               )

      assert read_args!(args_file) == [
               "threads",
               "replay",
               "T-123",
               "--wpm",
               "200",
               "--no-typing",
               "--message-delay",
               "10",
               "--tool-progress-delay",
               "20",
               "--exit-delay",
               "0",
               "--no-indicator"
             ]
    end)
  end

  test "mcp_add command supports workspace and env options" do
    with_cli_stub(fn args_file, _stdin_file ->
      assert {:ok, "ok"} =
               AmpSdk.mcp_add("echo-test", ["echo", "hello"],
                 workspace: true,
                 env: [{"A", "1"}, {"B", "2"}]
               )

      assert read_args!(args_file) == [
               "mcp",
               "add",
               "echo-test",
               "--workspace",
               "--env",
               "A=1",
               "--env",
               "B=2",
               "--",
               "echo",
               "hello"
             ]
    end)
  end

  test "mcp_add URL supports workspace and header options" do
    with_cli_stub(fn args_file, _stdin_file ->
      assert {:ok, "ok"} =
               AmpSdk.mcp_add("remote-test", "https://example.com/mcp",
                 workspace: true,
                 header: [{"Authorization", "Bearer token"}]
               )

      assert read_args!(args_file) == [
               "mcp",
               "add",
               "remote-test",
               "--workspace",
               "--header",
               "Authorization=Bearer token",
               "https://example.com/mcp"
             ]
    end)
  end

  test "mcp_list requests json output for typed parsing" do
    with_cli_stub(
      fn args_file, _stdin_file ->
        assert {:ok, []} = AmpSdk.mcp_list()

        assert read_args!(args_file) == [
                 "mcp",
                 "list",
                 "--json"
               ]
      end,
      %{"AMP_TEST_OUTPUT" => "[]"}
    )
  end

  test "mcp_oauth_login forwards current OAuth CLI flags" do
    with_cli_stub(fn args_file, _stdin_file ->
      assert {:ok, "ok"} =
               AmpSdk.mcp_oauth_login("oauth-server",
                 server_url: "https://example.com/mcp",
                 client_id: "client-id",
                 client_secret: "client-secret",
                 scopes: "read,write",
                 auth_url: "https://example.com/oauth/authorize",
                 token_url: "https://example.com/oauth/token"
               )

      assert read_args!(args_file) == [
               "mcp",
               "oauth",
               "login",
               "oauth-server",
               "--server-url",
               "https://example.com/mcp",
               "--client-id",
               "client-id",
               "--client-secret",
               "client-secret",
               "--scopes",
               "read,write",
               "--auth-url",
               "https://example.com/oauth/authorize",
               "--token-url",
               "https://example.com/oauth/token"
             ]
    end)
  end

  test "mcp_oauth_status and mcp_oauth_logout accept timeout options" do
    with_cli_stub(fn args_file, _stdin_file ->
      assert {:ok, "ok"} = AmpSdk.mcp_oauth_status("oauth-server", timeout: 1234)

      assert read_args!(args_file) == [
               "mcp",
               "oauth",
               "status",
               "oauth-server"
             ]
    end)

    with_cli_stub(fn args_file, _stdin_file ->
      assert {:ok, "ok"} = AmpSdk.mcp_oauth_logout("oauth-server", timeout: 2345)

      assert read_args!(args_file) == [
               "mcp",
               "oauth",
               "logout",
               "oauth-server"
             ]
    end)
  end

  test "threads_replay rewrites opaque CLI internal error with actionable guidance" do
    with_cli_stub(
      fn _args_file, _stdin_file ->
        assert {:error, %AmpSdk.Error{} = error} =
                 AmpSdk.threads_replay("T-123",
                   no_typing: true,
                   no_indicator: true,
                   exit_delay: 0
                 )

        assert error.message =~ "interactive terminal"
        assert error.details =~ "Unexpected error inside Amp CLI."
      end,
      %{
        "AMP_TEST_EXIT_CODE" => "1",
        "AMP_TEST_ERROR_TEXT" => "Error: Unexpected error inside Amp CLI."
      }
    )
  end

  test "tools_make forwards timeout option" do
    with_cli_stub(fn args_file, _stdin_file ->
      assert {:ok, "ok"} = AmpSdk.tools_make("my-tool", timeout: 9876)

      assert read_args!(args_file) == [
               "tools",
               "make",
               "my-tool"
             ]
    end)
  end
end
