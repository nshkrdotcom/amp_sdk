defmodule AmpSdk.Transport.ErlexecTest do
  use ExUnit.Case, async: false

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
        args: ["-c", "sleep 2"]
      )

    monitor_ref = Process.monitor(transport)

    subscriber =
      spawn(fn ->
        :ok = Erlexec.subscribe(transport, self(), make_ref())
        :timer.sleep(50)
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
end
