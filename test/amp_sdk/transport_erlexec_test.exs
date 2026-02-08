defmodule AmpSdk.Transport.ErlexecTest do
  use ExUnit.Case, async: false

  alias AmpSdk.TestSupport
  alias AmpSdk.Transport.Erlexec

  defp sh_path do
    System.find_executable("sh") || "sh"
  end

  test "streams stdout messages and exit events for namespaced subscribers" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "printf 'hello\\nworld\\n'"]
      )

    ref = make_ref()
    :ok = Erlexec.subscribe(transport, self(), ref)

    assert_receive {:amp_sdk_transport, ^ref, {:message, "hello"}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:message, "world"}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "start/1 wraps init failures as tagged transport errors" do
    assert {:error, {:transport, _reason}} =
             Erlexec.start(command: "sh", args: ["-c", "echo ok"], subscriber: :bad)
  end

  test "start_link/1 wraps init failures as tagged transport errors" do
    previous = Process.flag(:trap_exit, true)

    try do
      assert {:error, {:transport, _reason}} =
               Erlexec.start_link(command: "sh", args: ["-c", "echo ok"], subscriber: :bad)
    after
      Process.flag(:trap_exit, previous)
    end
  end

  test "flushes partial line on process exit" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "printf 'partial-line'"]
      )

    ref = make_ref()
    :ok = Erlexec.subscribe(transport, self(), ref)

    assert_receive {:amp_sdk_transport, ^ref, {:message, "partial-line"}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "emits buffer overflow and resumes at next complete line" do
    long_line = String.duplicate("a", 64)

    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "printf '#{long_line}\\nnext\\n'"],
        max_buffer_size: 16
      )

    ref = make_ref()
    :ok = Erlexec.subscribe(transport, self(), ref)

    assert_receive {:amp_sdk_transport, ^ref, {:error, {:buffer_overflow, 64}}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:message, "next"}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "captures stderr and emits it on exit" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "printf 'oops on stderr' >&2"]
      )

    ref = make_ref()
    :ok = Erlexec.subscribe(transport, self(), ref)

    assert_receive {:amp_sdk_transport, ^ref, {:stderr, stderr}}, 1_000
    assert stderr =~ "oops on stderr"
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "caps stderr buffer to configured tail size" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "printf '1234567890ABCDEFGHIJ' >&2"],
        max_stderr_buffer_size: 8
      )

    ref = make_ref()
    :ok = Erlexec.subscribe(transport, self(), ref)

    assert_receive {:amp_sdk_transport, ^ref, {:stderr, stderr}}, 1_000
    assert stderr == "CDEFGHIJ"
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "uses shared task supervisor without per-transport fallback supervisor allocation" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "cat"]
      )

    try do
      state = :sys.get_state(transport)

      assert state.task_supervisor == AmpSdk.TaskSupervisor
      assert Map.get(state, :io_supervisor) in [nil, AmpSdk.TaskSupervisor]
    after
      Erlexec.close(transport)
    end
  end

  test "safe_call uses the shared task supervisor for blocked client calls" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "cat"]
      )

    try do
      baseline_active = DynamicSupervisor.count_children(AmpSdk.TaskSupervisor).active
      :ok = :sys.suspend(transport)
      parent = self()

      caller =
        spawn(fn ->
          send(parent, {:status_result, Erlexec.status(transport)})
        end)

      assert TestSupport.wait_until(
               fn ->
                 DynamicSupervisor.count_children(AmpSdk.TaskSupervisor).active > baseline_active
               end,
               500
             ) == :ok

      :ok = :sys.resume(transport)
      assert_receive {:status_result, :connected}, 1_000
      refute Process.alive?(caller)
    after
      if Process.alive?(transport) do
        _ = Erlexec.force_close(transport)
      end
    end
  end

  test "supports end_input/1 for EOF driven commands" do
    cat = System.find_executable("cat") || "cat"

    {:ok, transport} = Erlexec.start(command: cat, args: [])
    ref = make_ref()
    :ok = Erlexec.subscribe(transport, self(), ref)

    assert :ok = Erlexec.send(transport, "echo me")
    assert :ok = Erlexec.end_input(transport)

    assert_receive {:amp_sdk_transport, ^ref, {:message, "echo me"}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "stops transport when last subscriber goes down" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "cat"]
      )

    monitor_ref = Process.monitor(transport)

    subscriber =
      spawn(fn ->
        :ok = Erlexec.subscribe(transport, self(), make_ref())

        receive do
        after
          50 ->
            :ok
        end
      end)

    Process.monitor(subscriber)

    assert_receive {:DOWN, _sub_ref, :process, ^subscriber, _}, 1_000
    assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _}, 1_500
  end

  test "returns typed not_connected errors when called after transport exits" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "exit 0"]
      )

    monitor_ref = Process.monitor(transport)
    assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _reason}, 1_000

    assert {:error, {:transport, :not_connected}} = Erlexec.send(transport, "echo me")
    assert {:error, {:transport, :not_connected}} = Erlexec.end_input(transport)

    assert {:error, {:transport, :not_connected}} =
             Erlexec.subscribe(transport, self(), make_ref())

    assert :disconnected = Erlexec.status(transport)
    assert "" = Erlexec.stderr(transport)
  end

  test "force_close/1 returns timeout error without killing an unresponsive transport" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "cat"]
      )

    monitor_ref = Process.monitor(transport)

    try do
      :ok = :sys.suspend(transport)

      assert {:error, {:transport, :timeout}} = Erlexec.force_close(transport)
      assert Process.alive?(transport)
      refute_received {:DOWN, ^monitor_ref, :process, ^transport, _reason}

      :ok = :sys.resume(transport)
      assert :ok = Erlexec.force_close(transport)
      assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _reason}, 1_500
    after
      if Process.alive?(transport) do
        _ = Process.exit(transport, :kill)
        assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _reason}, 1_500
      end
    end
  end

  test "headless transports auto-stop after idle timeout when no subscriber is attached" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "cat"],
        headless_timeout_ms: 50
      )

    monitor_ref = Process.monitor(transport)
    assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _reason}, 1_000
  end

  test "finalize exit draining remains responsive for status calls with large pending queues" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "cat"]
      )

    monitor_ref = Process.monitor(transport)

    try do
      state = :sys.get_state(transport)
      {pid, os_pid} = state.subprocess

      pending_lines =
        Enum.reduce(1..200_000, :queue.new(), fn _idx, queue ->
          :queue.in("line", queue)
        end)

      :sys.replace_state(transport, fn current ->
        %{current | pending_lines: pending_lines, stdout_buffer: "", drain_scheduled?: false}
      end)

      send(transport, {:finalize_exit, os_pid, pid, :normal})

      assert :connected = GenServer.call(transport, :status, 20)
      assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _reason}, 5_000
    after
      if Process.alive?(transport) do
        _ = Erlexec.force_close(transport)
        assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _reason}, 1_500
      end
    end
  end
end
