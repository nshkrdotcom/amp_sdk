defmodule AmpSdk.Transport.Erlexec do
  @moduledoc """
  Thin compatibility facade over `CliSubprocessCore.Transport`.

  This module remains only to preserve Amp's public transport module path and
  public event/error shapes. Subprocess lifecycle, shutdown, task supervision,
  and raw transport behavior are owned by the shared core.
  """

  import Kernel, except: [send: 2]

  alias CliSubprocessCore.ProcessExit, as: CoreProcessExit
  alias CliSubprocessCore.Transport, as: CoreTransport
  alias CliSubprocessCore.Transport.Error, as: CoreTransportError
  alias CliSubprocessCore.Transport.Options, as: CoreOptions

  @behaviour AmpSdk.Transport

  @core_event_tag :amp_sdk_core_transport
  defmodule SubscriberProxy do
    @moduledoc false

    alias AmpSdk.Transport.Erlexec
    alias CliSubprocessCore.ProcessExit, as: CoreProcessExit
    alias CliSubprocessCore.Transport.Error, as: CoreTransportError

    @core_event_tag :amp_sdk_core_transport
    @public_event_tag :amp_sdk_transport

    def start(target_pid, target_tag, max_stderr_buffer_size)
        when is_pid(target_pid) and is_reference(target_tag) do
      core_ref = make_ref()

      pid =
        spawn(fn ->
          target_monitor_ref = Process.monitor(target_pid)

          loop(%{
            target_pid: target_pid,
            target_tag: target_tag,
            target_monitor_ref: target_monitor_ref,
            transport_monitor_ref: nil,
            core_ref: core_ref,
            stderr: "",
            max_stderr_buffer_size: max_stderr_buffer_size
          })
        end)

      {:ok, pid, core_ref}
    end

    def attach_transport(proxy, transport) when is_pid(proxy) and is_pid(transport) do
      Kernel.send(proxy, {:attach_transport, transport})
      :ok
    end

    def stop(proxy) when is_pid(proxy) do
      Process.exit(proxy, :normal)
      :ok
    end

    defp loop(state) do
      receive do
        {:attach_transport, transport} when is_pid(transport) ->
          transport_monitor_ref = Process.monitor(transport)
          loop(%{state | transport_monitor_ref: transport_monitor_ref})

        {@core_event_tag, ref, {:message, line}}
        when ref == state.core_ref and is_binary(line) ->
          forward_event(state, {:message, line})
          loop(state)

        {@core_event_tag, ref, {:error, %CoreTransportError{} = error}}
        when ref == state.core_ref ->
          forward_event(state, {:error, Erlexec.legacy_transport_reason(error)})
          loop(state)

        {@core_event_tag, ref, {:stderr, data}}
        when ref == state.core_ref and is_binary(data) ->
          loop(%{
            state
            | stderr: append_stderr_tail(state.stderr, data, state.max_stderr_buffer_size)
          })

        {@core_event_tag, ref, {:exit, %CoreProcessExit{} = exit}} when ref == state.core_ref ->
          maybe_forward_stderr(state)
          forward_event(state, {:exit, exit.reason})
          cleanup_monitors(state)
          :ok

        {:DOWN, monitor_ref, :process, _pid, _reason}
        when monitor_ref == state.target_monitor_ref ->
          cleanup_monitors(state)
          :ok

        {:DOWN, monitor_ref, :process, _pid, _reason}
        when monitor_ref == state.transport_monitor_ref ->
          cleanup_monitors(state)
          :ok

        _other ->
          loop(state)
      end
    end

    defp maybe_forward_stderr(%{stderr: ""}), do: :ok

    defp maybe_forward_stderr(%{stderr: stderr} = state) do
      forward_event(state, {:stderr, stderr})
    end

    defp forward_event(%{target_pid: pid, target_tag: tag}, event) do
      Kernel.send(pid, {@public_event_tag, tag, event})
    end

    defp append_stderr_tail(_existing, _data, max_size)
         when not is_integer(max_size) or max_size <= 0,
         do: ""

    defp append_stderr_tail(existing, data, max_size) do
      combined = existing <> data
      combined_size = byte_size(combined)

      if combined_size <= max_size do
        combined
      else
        :binary.part(combined, combined_size - max_size, max_size)
      end
    end

    defp cleanup_monitors(%{target_monitor_ref: target_ref, transport_monitor_ref: transport_ref}) do
      Process.demonitor(target_ref, [:flush])
      if is_reference(transport_ref), do: Process.demonitor(transport_ref, [:flush])
    end
  end

  @impl AmpSdk.Transport
  def start(opts) when is_list(opts) do
    start_transport(&CoreTransport.start/1, opts)
  end

  @impl AmpSdk.Transport
  def start_link(opts) when is_list(opts) do
    start_transport(&CoreTransport.start_link/1, opts)
  end

  @impl AmpSdk.Transport
  def send(transport, message) when is_pid(transport) do
    CoreTransport.send(transport, message)
    |> legacy_reply()
  end

  @impl AmpSdk.Transport
  def subscribe(transport, pid, tag)
      when is_pid(transport) and is_pid(pid) and is_reference(tag) do
    max_stderr_buffer_size = transport_max_stderr_buffer_size(transport)
    {:ok, proxy, core_ref} = SubscriberProxy.start(pid, tag, max_stderr_buffer_size)

    case CoreTransport.subscribe(transport, proxy, core_ref) |> legacy_reply() do
      :ok ->
        SubscriberProxy.attach_transport(proxy, transport)
        :ok

      {:error, _reason} = error ->
        _ = SubscriberProxy.stop(proxy)
        error
    end
  end

  @impl AmpSdk.Transport
  def close(transport) when is_pid(transport), do: CoreTransport.close(transport)

  @impl AmpSdk.Transport
  def force_close(transport) when is_pid(transport) do
    case CoreTransport.force_close(transport) |> legacy_reply() do
      :ok -> :ok
      {:error, {:transport, :not_connected}} -> :ok
      {:error, _reason} = error -> error
    end
  end

  @impl AmpSdk.Transport
  def interrupt(transport) when is_pid(transport) do
    case CoreTransport.interrupt(transport) |> legacy_reply() do
      :ok -> :ok
      {:error, {:transport, :not_connected}} -> :ok
      {:error, _reason} = error -> error
    end
  end

  @impl AmpSdk.Transport
  def status(transport) when is_pid(transport), do: CoreTransport.status(transport)

  @impl AmpSdk.Transport
  def end_input(transport) when is_pid(transport) do
    CoreTransport.end_input(transport)
    |> legacy_reply()
  end

  @spec stderr(pid()) :: String.t()
  def stderr(transport) when is_pid(transport), do: CoreTransport.stderr(transport)

  defp start_transport(start_fun, opts) when is_function(start_fun, 1) and is_list(opts) do
    {subscriber, opts} = Keyword.pop(opts, :subscriber)
    normalized_opts = normalize_start_opts(opts)

    with {:ok, subscriber_proxy, core_subscriber} <-
           build_bootstrap_subscriber(subscriber, normalized_opts) do
      case maybe_add_subscriber(normalized_opts, core_subscriber)
           |> start_fun.()
           |> legacy_reply() do
        {:ok, transport} ->
          maybe_attach_bootstrap_proxy(subscriber_proxy, transport)
          {:ok, transport}

        {:error, _reason} = error ->
          maybe_stop_bootstrap_proxy(subscriber_proxy)
          error
      end
    else
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  defp normalize_start_opts(opts) do
    task_supervisor = Keyword.get_lazy(opts, :task_supervisor, &default_task_supervisor/0)

    opts
    |> Keyword.put(:task_supervisor, task_supervisor)
    |> Keyword.put_new(:event_tag, @core_event_tag)
    |> Keyword.put_new(:headless_timeout_ms, AmpSdk.Defaults.transport_headless_timeout_ms())
  end

  defp default_task_supervisor do
    case Application.ensure_all_started(:amp_sdk) do
      {:ok, _started_apps} -> AmpSdk.TaskSupervisor
      {:error, _reason} -> CliSubprocessCore.TaskSupervisor
    end
  end

  defp build_bootstrap_subscriber(nil, _opts), do: {:ok, nil, nil}

  defp build_bootstrap_subscriber({pid, tag}, opts)
       when is_pid(pid) and is_reference(tag) do
    max_size =
      Keyword.get(opts, :max_stderr_buffer_size, CoreOptions.default_max_stderr_buffer_size())

    {:ok, proxy, core_ref} = SubscriberProxy.start(pid, tag, max_size)
    {:ok, proxy, {proxy, core_ref}}
  end

  defp build_bootstrap_subscriber(subscriber, _opts),
    do: {:error, {:invalid_subscriber, subscriber}}

  defp maybe_add_subscriber(opts, nil), do: opts
  defp maybe_add_subscriber(opts, subscriber), do: Keyword.put(opts, :subscriber, subscriber)

  defp maybe_attach_bootstrap_proxy(nil, _transport), do: :ok

  defp maybe_attach_bootstrap_proxy(proxy, transport) when is_pid(proxy) and is_pid(transport) do
    SubscriberProxy.attach_transport(proxy, transport)
  end

  defp maybe_stop_bootstrap_proxy(nil), do: :ok
  defp maybe_stop_bootstrap_proxy(proxy) when is_pid(proxy), do: SubscriberProxy.stop(proxy)

  defp transport_max_stderr_buffer_size(transport) when is_pid(transport) do
    case :sys.get_state(transport) do
      %{max_stderr_buffer_size: max_size} when is_integer(max_size) -> max_size
      _other -> CoreOptions.default_max_stderr_buffer_size()
    end
  catch
    :exit, _reason ->
      CoreOptions.default_max_stderr_buffer_size()
  end

  defp legacy_reply(:ok), do: :ok

  defp legacy_reply({:ok, transport}) when is_pid(transport),
    do: {:ok, transport}

  defp legacy_reply({:error, {:transport, %CoreTransportError{} = error}}),
    do: {:error, {:transport, legacy_transport_reason(error)}}

  defp legacy_reply({:error, %CoreTransportError{} = error}),
    do: {:error, {:transport, legacy_transport_reason(error)}}

  defp legacy_reply(other), do: other

  def legacy_transport_reason(%CoreTransportError{
        reason: {:buffer_overflow, actual_size, _max_size}
      }),
      do: {:buffer_overflow, actual_size}

  def legacy_transport_reason(%CoreTransportError{
        reason: {:invalid_options, {:invalid_subscriber, subscriber}}
      }),
      do: {:invalid_subscriber, subscriber}

  def legacy_transport_reason(%CoreTransportError{reason: reason}), do: reason
  def legacy_transport_reason(reason), do: reason
end
