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

  test "start/1 preserves Amp bootstrap subscriber tagging" do
    ref = make_ref()

    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "printf 'boot\\n'"],
        subscriber: {self(), ref}
      )

    try do
      assert_receive {:amp_sdk_transport, ^ref, {:message, "boot"}}, 1_000
      assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
    after
      Erlexec.close(transport)
    end
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

  test "preserves Amp's public buffer overflow error shape" do
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

  test "captures fast-exit stderr for subscribers that attach after start" do
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

  test "supports interrupt/1 for in-flight subprocesses" do
    {:ok, transport} =
      Erlexec.start(
        command: sh_path(),
        args: ["-c", "cat"]
      )

    try do
      assert :ok = Erlexec.interrupt(transport)
    after
      _ = Erlexec.force_close(transport)
    end
  end
end
