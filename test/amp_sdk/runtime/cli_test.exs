defmodule AmpSdk.Runtime.CLITest do
  use ExUnit.Case, async: false

  alias AmpSdk.Runtime.CLI
  alias AmpSdk.TestSupport
  alias AmpSdk.Types
  alias AmpSdk.Types.{Options, Permission}
  alias CliSubprocessCore.{Event, ExecutionSurface, Payload, ProcessExit, TransportError}
  alias CliSubprocessCore.TestSupport.FakeSSH

  defp write_runtime_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail
    sleep 60
    """

    TestSupport.write_executable!(dir, "amp", script)
  end

  describe "start_session/1" do
    test "builds a core session with Amp-compatible invocation args and env" do
      dir = TestSupport.tmp_dir!("amp_runtime_cli")
      stub_path = write_runtime_stub!(dir)
      session_ref = make_ref()

      options = %Options{
        mode: "smart",
        visibility: "private",
        continue_thread: "T-abc123",
        log_level: "debug",
        log_file: "/tmp/amp.log",
        thinking: true,
        labels: ["ci", "sdk"],
        mcp_config: %{"server" => %{"command" => "npx"}},
        permissions: [Permission.new!("Bash", "allow")],
        skills: "/tmp/skills",
        toolbox: "/tmp/toolbox",
        no_ide: true,
        no_notifications: true,
        no_color: true,
        no_jetbrains: true,
        env: %{"AMP_TEST_RUNTIME" => "1"}
      }

      try do
        TestSupport.with_env(%{"AMP_CLI_PATH" => stub_path}, fn ->
          assert {:ok, session, %{info: info}} =
                   CLI.start_session(
                     input: "hello from runtime",
                     options: options,
                     subscriber: {self(), session_ref}
                   )

          assert info.provider == :amp
          assert info.runtime.provider == :amp
          assert info.invocation.command == stub_path
          assert info.invocation.cwd == File.cwd!()
          assert info.invocation.env["AMP_TEST_RUNTIME"] == "1"
          assert info.invocation.env["AMP_TOOLBOX"] == "/tmp/toolbox"
          assert info.invocation.env["AMP_SDK_VERSION"] =~ "elixir-"

          args = info.invocation.args

          assert "threads" in args
          assert "continue" in args
          assert "T-abc123" in args
          execute_idx = Enum.find_index(args, &(&1 == "--execute"))
          assert is_integer(execute_idx)
          assert Enum.at(args, execute_idx + 1) == "hello from runtime"
          assert "--stream-json-thinking" in args
          assert "--visibility" in args
          assert "--log-level" in args
          assert "--log-file" in args
          assert "--mcp-config" in args
          assert "--label" in args
          assert "--no-ide" in args
          assert "--no-notifications" in args
          assert "--no-color" in args
          assert "--no-jetbrains" in args

          settings_idx = Enum.find_index(args, &(&1 == "--settings-file"))
          assert is_integer(settings_idx)

          settings_path = Enum.at(args, settings_idx + 1)
          assert is_binary(settings_path)
          assert File.exists?(settings_path)
          assert Path.dirname(settings_path) == System.tmp_dir!()
          assert File.stat!(settings_path).mode |> Bitwise.band(0o777) == 0o600

          session_monitor_ref = Process.monitor(session)
          assert :ok = CLI.close(session)
          assert_receive {:DOWN, ^session_monitor_ref, :process, ^session, :normal}, 2_000
          assert TestSupport.wait_until(fn -> not File.exists?(settings_path) end, 1_000) == :ok
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "preserves execution_surface through the shared session lane" do
      dir = TestSupport.tmp_dir!("amp_runtime_cli_fake_ssh")
      _stub_path = write_runtime_stub!(dir)
      fake_ssh = FakeSSH.new!()
      session_ref = make_ref()

      options = %Options{
        execution_surface: %ExecutionSurface{
          surface_kind: :ssh_exec,
          transport_options:
            FakeSSH.transport_options(fake_ssh,
              destination: "runtime.ssh.example",
              ssh_options: [BatchMode: "yes"]
            ),
          target_id: "amp-runtime-target"
        },
        env: %{
          "PATH" => dir <> ":" <> (System.get_env("PATH") || "")
        }
      }

      try do
        assert {:ok, session, %{info: info}} =
                 CLI.start_session(
                   input: "hello over ssh",
                   options: options,
                   subscriber: {self(), session_ref}
                 )

        assert info.transport.info.surface_kind == :ssh_exec
        assert info.transport.info.target_id == "amp-runtime-target"
        assert info.transport.info.adapter_metadata.destination == "runtime.ssh.example"
        assert info.transport.info.adapter_metadata.ssh_path == fake_ssh.ssh_path

        assert FakeSSH.wait_until_written(fake_ssh, 1_000) == :ok
        assert FakeSSH.read_manifest!(fake_ssh) =~ "destination=runtime.ssh.example"
        session_monitor_ref = Process.monitor(session)
        assert :ok = CLI.close(session)
        assert_receive {:DOWN, ^session_monitor_ref, :process, ^session, :normal}, 2_000
      after
        FakeSSH.cleanup(fake_ssh)
        File.rm_rf(dir)
      end
    end

    test "does not leak the local cwd into remote session invocations" do
      dir = TestSupport.tmp_dir!("amp_runtime_cli_remote_cwd")
      _stub_path = write_runtime_stub!(dir)
      fake_ssh = FakeSSH.new!()
      session_ref = make_ref()

      options = %Options{
        execution_surface: %ExecutionSurface{
          surface_kind: :ssh_exec,
          transport_options:
            FakeSSH.transport_options(fake_ssh, destination: "amp-runtime.cwd.example")
        },
        env: %{"PATH" => dir <> ":" <> (System.get_env("PATH") || "")}
      }

      try do
        assert {:ok, session, %{info: info}} =
                 CLI.start_session(
                   input: "hello over ssh",
                   options: options,
                   subscriber: {self(), session_ref}
                 )

        assert info.invocation.cwd == nil

        session_monitor_ref = Process.monitor(session)
        assert :ok = CLI.close(session)
        assert_receive {:DOWN, ^session_monitor_ref, :process, ^session, :normal}, 2_000
      after
        FakeSSH.cleanup(fake_ssh)
        File.rm_rf(dir)
      end
    end

    test "removes owner-tracked settings when the core session is killed" do
      dir = TestSupport.tmp_dir!("amp_runtime_settings_owner")
      stub_path = write_runtime_stub!(dir)

      try do
        TestSupport.with_env(%{"AMP_CLI_PATH" => stub_path}, fn ->
          assert {:ok, session, %{info: info}} =
                   CLI.start_session(
                     input: "owner cleanup",
                     options: %Options{permissions: [Permission.new!("Bash", "ask")]},
                     subscriber: {self(), make_ref()}
                   )

          settings_idx = Enum.find_index(info.invocation.args, &(&1 == "--settings-file"))
          settings_path = Enum.at(info.invocation.args, settings_idx + 1)

          assert File.exists?(settings_path)
          assert File.stat!(settings_path).mode |> Bitwise.band(0o777) == 0o600

          monitor_ref = Process.monitor(session)
          Process.exit(session, :kill)
          assert_receive {:DOWN, ^monitor_ref, :process, ^session, :killed}, 2_000
          assert TestSupport.wait_until(fn -> not File.exists?(settings_path) end, 1_000) == :ok
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "rejects unsupported common options before CLI resolution" do
      TestSupport.with_env(%{"AMP_CLI_PATH" => "/definitely/missing/amp"}, fn ->
        assert {:error, %CliSubprocessCore.ProviderFeatures.Error{} = error} =
                 CLI.start_session(
                   input: "unsupported",
                   options: %Options{completion_only: true}
                 )

        assert error.provider == :amp
        assert error.feature == :completion_only
        assert error.option == :completion_only
        assert error.support_state == :unsupported
      end)
    end
  end

  describe "Profile.transport_options/1" do
    test "closes stdin on start only for prompt mode" do
      assert CLI.Profile.transport_options(input_mode: :prompt)[:close_stdin_on_start?] == true

      assert CLI.Profile.transport_options(input_mode: :json_input)[:close_stdin_on_start?] ==
               false
    end

    test "threads the declared finite orphan-reap timeout to the transport" do
      transport_options =
        CLI.Profile.transport_options(
          input_mode: :prompt,
          transport_headless_timeout_ms: 25
        )

      assert transport_options[:headless_timeout_ms] == 25
    end
  end

  describe "session control surfaces" do
    test "capabilities publish session control support" do
      assert :session_history in CLI.capabilities()
      assert :session_resume in CLI.capabilities()
      assert :session_pause in CLI.capabilities()
      assert :session_intervene in CLI.capabilities()
    end

    test "list_provider_sessions/1 returns standardized Amp thread entries" do
      dir = TestSupport.tmp_dir!("amp_runtime_thread_entries")

      script = """
      #!/usr/bin/env bash
      set -euo pipefail
      printf '%s\n' \
        'Title                                         Last Updated  Visibility  Messages  Thread ID' \
        '────────────────────────────────────────────  ────────────  ──────────  ────────  ──────────────────────────────────────' \
        'OTP refactor tracking                         2m ago        Workspace          4  T-01234567-89ab-cdef-0123-456789abcdef'
      """

      stub_path = TestSupport.write_executable!(dir, "amp_runtime_threads_stub", script)

      try do
        TestSupport.with_env(%{"AMP_CLI_PATH" => stub_path}, fn ->
          assert {:ok, [entry]} = CLI.list_provider_sessions()
          assert entry.id == "T-01234567-89ab-cdef-0123-456789abcdef"
          assert entry.label == "OTP refactor tracking"
          assert entry.updated_at == "2m ago"
          assert entry.source_kind == :thread_history
          assert entry.metadata.visibility == :workspace
          assert entry.metadata.messages == 4
        end)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "project_event/2" do
    test "synthesizes a system message and projects assistant/tool/result events" do
      state = CLI.new_projection_state(%{invocation: %{cwd: "/tmp/demo"}})

      delta_event =
        Event.new(:assistant_delta,
          provider: :amp,
          provider_session_id: "amp-session-1",
          raw: %{"type" => "message_streamed", "delta" => "Hel", "session_id" => "amp-session-1"},
          payload: Payload.AssistantDelta.new(content: "Hel")
        )

      assert {[system_message, assistant_delta], state} = CLI.project_event(delta_event, state)

      assert %Types.SystemMessage{session_id: "amp-session-1", cwd: "/tmp/demo"} = system_message

      assert %Types.AssistantMessage{
               session_id: "amp-session-1",
               message: %{content: [%Types.TextContent{text: "Hel"}]}
             } = assistant_delta

      tool_use_event =
        Event.new(:tool_use,
          provider: :amp,
          provider_session_id: "amp-session-1",
          raw: %{
            "type" => "tool_call_started",
            "tool_name" => "bash",
            "tool_call_id" => "tool-4",
            "tool_input" => %{"cmd" => "pwd"}
          },
          payload:
            Payload.ToolUse.new(
              tool_name: "bash",
              tool_call_id: "tool-4",
              input: %{"cmd" => "pwd"}
            )
        )

      assert {[assistant_tool_use], state} = CLI.project_event(tool_use_event, state)

      assert %Types.AssistantMessage{
               message: %{
                 content: [
                   %Types.ToolUseContent{id: "tool-4", name: "bash", input: %{"cmd" => "pwd"}}
                 ]
               }
             } = assistant_tool_use

      tool_result_event =
        Event.new(:tool_result,
          provider: :amp,
          provider_session_id: "amp-session-1",
          raw: %{
            "type" => "tool_call_completed",
            "tool_call_id" => "tool-4",
            "tool_output" => "/tmp"
          },
          payload:
            Payload.ToolResult.new(tool_call_id: "tool-4", content: "/tmp", is_error: false)
        )

      assert {[user_tool_result], state} = CLI.project_event(tool_result_event, state)

      assert %Types.UserMessage{
               message: %{
                 content: [%Types.ToolResultContent{tool_use_id: "tool-4", content: "/tmp"}]
               }
             } = user_tool_result

      result_event =
        Event.new(:result,
          provider: :amp,
          provider_session_id: "amp-session-1",
          raw: %{
            "type" => "run_completed",
            "result" => "Hello",
            "duration_ms" => 300,
            "num_turns" => 2,
            "token_usage" => %{"input_tokens" => 7, "output_tokens" => 9}
          },
          payload:
            Payload.Result.new(
              status: :completed,
              stop_reason: "done",
              output: %{
                result: "provider-result",
                duration_ms: 300,
                duration_api_ms: 250,
                num_turns: 2,
                usage: %{input_tokens: 7, output_tokens: 9, total_tokens: 16},
                cost_usd: 0.42,
                permission_denials: [%{tool: "Bash", reason: "policy"}]
              },
              object: nil,
              metadata: %{subtype: "success", provider_status: "completed"}
            )
        )

      assert {[result_message], _state} = CLI.project_event(result_event, state)

      assert %Types.ResultMessage{
               session_id: "amp-session-1",
               provider_session_id: "amp-session-1",
               result: "provider-result",
               status: :completed,
               stop_reason: "done",
               duration_ms: 300,
               duration_api_ms: 250,
               num_turns: 2,
               usage: %Types.Usage{input_tokens: 7, output_tokens: 9},
               cost_usd: 0.42,
               permission_denials: [%{"tool" => "Bash", "reason" => "policy"}],
               metadata: %{subtype: "success", provider_status: "completed"},
               raw: %{"type" => "run_completed"}
             } = result_message

      assert result_message.output.result == "provider-result"
    end

    test "projects parse and transport exit failures into Amp error result messages" do
      parse_state = CLI.new_projection_state(%{invocation: %{cwd: "/tmp/demo"}})

      parse_error =
        Event.new(:error,
          provider: :amp,
          provider_session_id: "amp-session-2",
          raw: "{broken json",
          payload:
            Payload.Error.new(
              message: "unexpected byte at position 1",
              code: "parse_error",
              metadata: %{line: "{broken json"}
            )
        )

      assert {parse_events, _state} = CLI.project_event(parse_error, parse_state)
      assert %Types.ErrorResultMessage{kind: :parse_error} = List.last(parse_events)
      assert List.last(parse_events).error =~ "JSON parse error"

      exit_state = CLI.new_projection_state(%{invocation: %{cwd: "/tmp/demo"}})

      exit_error =
        Event.new(:error,
          provider: :amp,
          provider_session_id: "amp-session-3",
          raw: %{exit: ProcessExit.from_reason({:exit_status, 7})},
          payload:
            Payload.Error.new(
              message: "CLI exited with code 7",
              code: "transport_exit",
              metadata: %{exit: %{code: 7}}
            )
        )

      assert {exit_events, _state} = CLI.project_event(exit_error, exit_state)

      assert %Types.ErrorResultMessage{kind: :transport_exit, exit_code: 7} =
               List.last(exit_events)

      assert List.last(exit_events).error =~ "code 7"
    end

    test "projects former transport-wrapper transport errors into typed Amp error results" do
      state = CLI.new_projection_state(%{invocation: %{cwd: "/tmp/demo"}})

      transport_error =
        Event.new(:error,
          provider: :amp,
          provider_session_id: "amp-session-transport-error",
          raw:
            TransportError.transport_error(
              {:buffer_overflow, 64, 16},
              %{actual_size: 64, max_size: 16, preview: "aaaaaaaa"}
            ),
          payload:
            Payload.Error.new(
              message: "Transport buffer exceeded 16 bytes (got 64)",
              code: "transport_error",
              metadata: %{actual_size: 64, max_size: 16}
            )
        )

      assert {[system_message, error_message], _state} = CLI.project_event(transport_error, state)
      assert %Types.SystemMessage{session_id: "amp-session-transport-error"} = system_message

      assert %Types.ErrorResultMessage{
               session_id: "amp-session-transport-error",
               kind: :transport_error,
               error: "Transport error: Transport buffer exceeded 16 bytes (got 64)",
               details: %{"actual_size" => 64, "max_size" => 16, "preview" => "aaaaaaaa"}
             } = error_message
    end

    test "projects unknown provider error codes as bounded unknown kinds" do
      state = CLI.new_projection_state(%{invocation: %{cwd: "/tmp/demo"}})

      provider_error =
        Event.new(:error,
          provider: :amp,
          provider_session_id: "amp-session-future-error",
          raw: %{"type" => "future_error", "future_code" => "provider_added_new_code"},
          payload:
            Payload.Error.new(
              message: "provider added a new code",
              code: "provider_added_new_code",
              metadata: %{"phase" => "future"}
            )
        )

      assert {[system_message, error_message], _state} = CLI.project_event(provider_error, state)
      assert %Types.SystemMessage{session_id: "amp-session-future-error"} = system_message

      assert %Types.ErrorResultMessage{
               session_id: "amp-session-future-error",
               kind: :unknown,
               error: "provider added a new code",
               details: %{
                 "future_code" => "provider_added_new_code",
                 "phase" => "future",
                 "type" => "future_error"
               }
             } = error_message
    end

    test "synthesizes a system message when the first session id arrives on a result" do
      state = CLI.new_projection_state(%{invocation: %{cwd: "/tmp/demo"}})

      result_event =
        Event.new(:result,
          provider: :amp,
          provider_session_id: "T-result-only",
          raw: %{
            "type" => "run_completed",
            "session_id" => "T-result-only",
            "result" => "Hello",
            "duration_ms" => 300,
            "num_turns" => 1
          },
          payload: Payload.Result.new(status: :completed, stop_reason: "done", output: %{})
        )

      assert {[system_message, result_message], state} = CLI.project_event(result_event, state)
      assert %Types.SystemMessage{session_id: "T-result-only", cwd: "/tmp/demo"} = system_message
      assert %Types.ResultMessage{session_id: "T-result-only", result: "Hello"} = result_message
      assert state.system_emitted? == true
    end

    test "synthesizes a system message when the first session id arrives on an error" do
      state = CLI.new_projection_state(%{invocation: %{cwd: "/tmp/demo"}})

      error_event =
        Event.new(:error,
          provider: :amp,
          provider_session_id: "T-error-only",
          raw: %{
            "type" => "run_failed",
            "session_id" => "T-error-only",
            "error" => "boom"
          },
          payload: Payload.Error.new(message: "boom", code: "execution_failed")
        )

      assert {[system_message, error_message], state} = CLI.project_event(error_event, state)
      assert %Types.SystemMessage{session_id: "T-error-only", cwd: "/tmp/demo"} = system_message
      assert %Types.ErrorResultMessage{session_id: "T-error-only", error: "boom"} = error_message
      assert state.system_emitted? == true
    end
  end
end
