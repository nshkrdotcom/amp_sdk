defmodule AmpSdk.TransportTest do
  use ExUnit.Case, async: false

  alias AmpSdk.Transport

  defp sh_path do
    System.find_executable("sh") || "sh"
  end

  test "streams stdout messages and exit events for namespaced subscribers" do
    {:ok, transport} =
      Transport.start(
        command: sh_path(),
        args: ["-c", "sleep 0.05; printf 'hello\\nworld\\n'"]
      )

    ref = make_ref()
    :ok = Transport.subscribe(transport, self(), ref)

    assert_receive {:amp_sdk_transport, ^ref, {:message, "hello"}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:message, "world"}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "start/1 preserves Amp bootstrap subscriber tagging" do
    ref = make_ref()

    {:ok, transport} =
      Transport.start(
        command: sh_path(),
        args: ["-c", "printf 'boot\\n'"],
        subscriber: {self(), ref}
      )

    try do
      assert_receive {:amp_sdk_transport, ^ref, {:message, "boot"}}, 1_000
      assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
    after
      Transport.close(transport)
    end
  end

  test "start/1 wraps init failures as tagged transport errors" do
    assert {:error, {:transport, _reason}} =
             Transport.start(command: "sh", args: ["-c", "echo ok"], subscriber: :bad)
  end

  test "start_link/1 wraps init failures as tagged transport errors" do
    previous = Process.flag(:trap_exit, true)

    try do
      assert {:error, {:transport, _reason}} =
               Transport.start_link(command: "sh", args: ["-c", "echo ok"], subscriber: :bad)
    after
      Process.flag(:trap_exit, previous)
    end
  end

  test "preserves Amp's public buffer overflow error shape" do
    long_line = String.duplicate("a", 64)

    {:ok, transport} =
      Transport.start(
        command: sh_path(),
        args: ["-c", "printf '#{long_line}\\nnext\\n'"],
        max_buffer_size: 16
      )

    ref = make_ref()
    :ok = Transport.subscribe(transport, self(), ref)

    assert_receive {:amp_sdk_transport, ^ref, {:error, {:buffer_overflow, 64}}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:message, "next"}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "forwards stderr chunks before exit when the subprocess stays alive" do
    ref = make_ref()

    {:ok, _transport} =
      Transport.start(
        command: sh_path(),
        args: ["-c", "printf 'warn' >&2; sleep 0.1"],
        subscriber: {self(), ref}
      )

    assert_receive {:amp_sdk_transport, ^ref, {:stderr, "warn"}}, 1_000
    refute_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 20
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "captures fast-exit stderr for subscribers that attach after start" do
    {:ok, transport} =
      Transport.start(
        command: sh_path(),
        args: ["-c", "printf 'oops on stderr' >&2"]
      )

    ref = make_ref()
    :ok = Transport.subscribe(transport, self(), ref)

    assert_receive {:amp_sdk_transport, ^ref, {:stderr, stderr}}, 1_000
    assert stderr =~ "oops on stderr"
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "caps stderr buffer to configured tail size" do
    {:ok, transport} =
      Transport.start(
        command: sh_path(),
        args: ["-c", "printf '1234567890ABCDEFGHIJ' >&2"],
        max_stderr_buffer_size: 8
      )

    ref = make_ref()
    :ok = Transport.subscribe(transport, self(), ref)

    assert_receive {:amp_sdk_transport, ^ref, {:stderr, stderr}}, 1_000
    assert stderr == "1234567890ABCDEFGHIJ"
    assert Transport.stderr(transport) == "CDEFGHIJ"
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "supports end_input/1 for EOF driven commands" do
    cat = System.find_executable("cat") || "cat"

    {:ok, transport} = Transport.start(command: cat, args: [])
    ref = make_ref()
    :ok = Transport.subscribe(transport, self(), ref)

    assert :ok = Transport.send(transport, "echo me")
    assert :ok = Transport.end_input(transport)

    assert_receive {:amp_sdk_transport, ^ref, {:message, "echo me"}}, 1_000
    assert_receive {:amp_sdk_transport, ^ref, {:exit, _reason}}, 1_000
  end

  test "returns typed not_connected errors when called after transport exits" do
    {:ok, transport} =
      Transport.start(
        command: sh_path(),
        args: ["-c", "exit 0"]
      )

    monitor_ref = Process.monitor(transport)
    assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _reason}, 1_000

    assert {:error, {:transport, :not_connected}} = Transport.send(transport, "echo me")
    assert {:error, {:transport, :not_connected}} = Transport.end_input(transport)

    assert {:error, {:transport, :not_connected}} =
             Transport.subscribe(transport, self(), make_ref())

    assert :disconnected = Transport.status(transport)
    assert "" = Transport.stderr(transport)
  end

  test "supports interrupt/1 for in-flight subprocesses" do
    {:ok, transport} =
      Transport.start(
        command: sh_path(),
        args: ["-c", "cat"]
      )

    try do
      assert :ok = Transport.interrupt(transport)
    after
      _ = Transport.force_close(transport)
    end
  end
end
