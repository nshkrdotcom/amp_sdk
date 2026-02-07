defmodule AmpSdk.WrappersBehaviorTest do
  use ExUnit.Case, async: false

  alias AmpSdk.{MCP, Permissions, Review, Skills, Tasks, Threads, Tools, Usage}
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

    echo "${AMP_TEST_OUTPUT:-ok}"
    """

    TestSupport.write_executable!(dir, "amp_stub", script)
  end

  test "threads and review wrappers build expected arguments" do
    dir = TestSupport.tmp_dir!("amp_wrappers")
    args_file = Path.join(dir, "args.txt")
    amp_path = write_amp_stub!(dir)

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path, "AMP_TEST_ARGS_FILE" => args_file}, fn ->
        assert {:ok, "ok"} = Threads.search("bug", limit: 3, offset: 1, json: true)

        assert File.read!(args_file) ==
                 "threads\nsearch\nbug\n--limit\n3\n--offset\n1\n--json\n"

        assert {:ok, "ok"} =
                 Review.run(
                   dangerously_allow_all: true,
                   diff: "HEAD~1",
                   files: ["lib/app.ex"],
                   instructions: "check",
                   check_scope: "security",
                   check_filter: ["critical"],
                   summary_only: true
                 )

        assert File.read!(args_file) ==
                 "--dangerously-allow-all\nreview\nHEAD~1\n--files\nlib/app.ex\n--instructions\ncheck\n--check-scope\nsecurity\n--check-filter\ncritical\n--summary-only\n"
      end)
    after
      File.rm_rf(dir)
    end
  end

  test "tools and mcp wrappers forward stdin and options" do
    dir = TestSupport.tmp_dir!("amp_wrappers")
    args_file = Path.join(dir, "args.txt")
    stdin_file = Path.join(dir, "stdin.txt")
    amp_path = write_amp_stub!(dir)

    try do
      TestSupport.with_env(
        %{
          "AMP_CLI_PATH" => amp_path,
          "AMP_TEST_ARGS_FILE" => args_file,
          "AMP_TEST_STDIN_FILE" => stdin_file
        },
        fn ->
          assert {:ok, "ok"} =
                   Tools.use("grep",
                     only: "stdout",
                     stream: true,
                     args: [{:pattern, "TODO"}, "lib"],
                     input: "sample input"
                   )

          assert File.read!(args_file) ==
                   "tools\nuse\ngrep\n--only\nstdout\n--stream\n--pattern\nTODO\nlib\n"

          assert File.read!(stdin_file) == "sample input"

          TestSupport.with_env(%{"AMP_TEST_STDIN_FILE" => nil}, fn ->
            assert {:ok, "ok"} =
                     MCP.add("filesystem", ["npx", "-y", "server"], env: %{"A" => "1"})

            assert File.read!(args_file) ==
                     "mcp\nadd\nfilesystem\n--env\nA=1\n--\nnpx\n-y\nserver\n"
          end)
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "other wrappers execute through shared command path" do
    dir = TestSupport.tmp_dir!("amp_wrappers")
    args_file = Path.join(dir, "args.txt")
    amp_path = write_amp_stub!(dir)

    try do
      TestSupport.with_env(%{"AMP_CLI_PATH" => amp_path, "AMP_TEST_ARGS_FILE" => args_file}, fn ->
        assert {:ok, "ok"} = Skills.list()
        assert File.read!(args_file) == "skill\nlist\n"

        assert {:ok, "ok"} =
                 Permissions.add("Bash", "ask",
                   context: "thread",
                   to: "policy-proxy",
                   workspace: true
                 )

        assert File.read!(args_file) ==
                 "permissions\nadd\nask\nBash\n--context\nthread\n--to\npolicy-proxy\n--workspace\n"

        assert {:ok, "ok"} = Tasks.list()
        assert File.read!(args_file) == "tasks\nlist\n"

        assert {:ok, "ok"} = Usage.info()
        assert File.read!(args_file) == "usage\n"
      end)
    after
      File.rm_rf(dir)
    end
  end
end
