defmodule AmpSdk.Transport.Erlexec do
  @moduledoc """
  Thin compatibility wrapper around `CliSubprocessCore.Transport.Erlexec`.
  """

  import Kernel, except: [send: 2]

  alias CliSubprocessCore.ProcessExit, as: CoreProcessExit
  alias CliSubprocessCore.Transport.Erlexec, as: CoreErlexec
  alias CliSubprocessCore.Transport.Error, as: CoreTransportError
  alias CliSubprocessCore.Transport.Options, as: CoreOptions

  @behaviour AmpSdk.Transport

  @core_event_tag :amp_sdk_core_transport
  @default_call_timeout AmpSdk.Defaults.transport_call_timeout_ms()
  @default_force_close_timeout AmpSdk.Defaults.transport_force_close_timeout_ms()
  defmodule SubscriberProxy do
    @moduledoc false

    alias AmpSdk.Transport.Erlexec
    alias CliSubprocessCore.ProcessExit, as: CoreProcessExit
    alias CliSubprocessCore.Transport.Erlexec, as: CoreErlexec
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
            transport: nil,
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
          loop(%{state | transport: transport, transport_monitor_ref: transport_monitor_ref})

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
          maybe_detach_transport(state)
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

    defp maybe_detach_transport(%{transport: transport} = state) when is_pid(transport) do
      _ = CoreErlexec.unsubscribe(transport, self())

      if transport_subscriber_count(transport) == 0 do
        _ = CoreErlexec.close(transport)
      end

      state
    end

    defp maybe_detach_transport(state), do: state

    defp transport_subscriber_count(transport) when is_pid(transport) do
      case :sys.get_state(transport) do
        %{subscribers: subscribers} when is_map(subscribers) -> map_size(subscribers)
        _other -> 0
      end
    catch
      :exit, _reason -> 0
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
      if is_reference(target_ref), do: Process.demonitor(target_ref, [:flush])
      if is_reference(transport_ref), do: Process.demonitor(transport_ref, [:flush])
    end
  end

  @impl AmpSdk.Transport
  def start(opts) when is_list(opts) do
    start_transport(:start, opts)
  end

  @impl AmpSdk.Transport
  def start_link(opts) when is_list(opts) do
    start_transport(:start_link, opts)
  end

  @impl AmpSdk.Transport
  def send(transport, message) when is_pid(transport) do
    case safe_call(transport, {:send, message}) do
      {:ok, result} -> legacy_reply(result)
      {:error, reason} -> transport_error(reason)
    end
  end

  @impl AmpSdk.Transport
  def subscribe(transport, pid, tag)
      when is_pid(transport) and is_pid(pid) and is_reference(tag) do
    max_stderr_buffer_size = transport_max_stderr_buffer_size(transport)
    {:ok, proxy, core_ref} = SubscriberProxy.start(pid, tag, max_stderr_buffer_size)

    case subscribe_proxy(transport, proxy, core_ref) do
      :ok ->
        SubscriberProxy.attach_transport(proxy, transport)
        :ok

      {:error, reason} ->
        transport_error(reason)
    end
  end

  @impl AmpSdk.Transport
  def close(transport) when is_pid(transport), do: CoreErlexec.close(transport)

  @impl AmpSdk.Transport
  def force_close(transport) when is_pid(transport) do
    case safe_call(transport, :force_close, @default_force_close_timeout) do
      {:ok, :ok} -> :ok
      {:error, :not_connected} -> :ok
      {:error, reason} -> transport_error(reason)
    end
  end

  @impl AmpSdk.Transport
  def interrupt(transport) when is_pid(transport) do
    case safe_call(transport, :interrupt) do
      {:ok, :ok} -> :ok
      {:error, :not_connected} -> :ok
      {:error, reason} -> transport_error(reason)
    end
  end

  @impl AmpSdk.Transport
  def status(transport) when is_pid(transport) do
    case safe_call(transport, :status) do
      {:ok, status} when status in [:connected, :disconnected, :error] -> status
      {:ok, _other} -> :error
      {:error, _reason} -> :disconnected
    end
  end

  @impl AmpSdk.Transport
  def end_input(transport) when is_pid(transport) do
    case safe_call(transport, :end_input) do
      {:ok, result} -> legacy_reply(result)
      {:error, reason} -> transport_error(reason)
    end
  end

  @spec stderr(pid()) :: String.t()
  def stderr(transport) when is_pid(transport) do
    case safe_call(transport, :stderr) do
      {:ok, value} when is_binary(value) -> value
      _other -> ""
    end
  end

  defp start_transport(mode, opts) when mode in [:start, :start_link] do
    {subscriber, opts} = Keyword.pop(opts, :subscriber)

    with {:ok, normalized_opts} <- normalize_start_opts(opts),
         {:ok, subscriber_proxy, core_subscriber} <-
           build_bootstrap_subscriber(subscriber, normalized_opts) do
      case start_core_transport(mode, normalized_opts, core_subscriber) do
        {:ok, transport} ->
          maybe_attach_bootstrap_proxy(subscriber_proxy, transport)
          {:ok, transport}

        {:error, reason} ->
          maybe_stop_bootstrap_proxy(subscriber_proxy)
          transport_error(reason)
      end
    else
      {:error, reason} ->
        transport_error(reason)
    end
  end

  defp normalize_start_opts(opts) do
    opts =
      opts
      |> Keyword.put_new(:task_supervisor, AmpSdk.TaskSupervisor)
      |> Keyword.put_new(:event_tag, @core_event_tag)
      |> Keyword.put_new(:headless_timeout_ms, AmpSdk.Defaults.transport_headless_timeout_ms())

    case CoreOptions.new(opts) do
      {:ok, options} -> {:ok, options}
      {:error, {:invalid_transport_options, reason}} -> {:error, {:invalid_options, reason}}
    end
  end

  defp build_bootstrap_subscriber(nil, _options), do: {:ok, nil, nil}

  defp build_bootstrap_subscriber({pid, tag}, %CoreOptions{} = options)
       when is_pid(pid) and is_reference(tag) do
    {:ok, proxy, core_ref} = SubscriberProxy.start(pid, tag, options.max_stderr_buffer_size)
    {:ok, proxy, {proxy, core_ref}}
  end

  defp build_bootstrap_subscriber(subscriber, _options),
    do: {:error, {:invalid_subscriber, subscriber}}

  defp maybe_attach_bootstrap_proxy(nil, _transport), do: :ok

  defp maybe_attach_bootstrap_proxy(proxy, transport) when is_pid(proxy) and is_pid(transport) do
    SubscriberProxy.attach_transport(proxy, transport)
  end

  defp maybe_stop_bootstrap_proxy(nil), do: :ok
  defp maybe_stop_bootstrap_proxy(proxy) when is_pid(proxy), do: SubscriberProxy.stop(proxy)

  defp start_core_transport(mode, %CoreOptions{} = options, nil) do
    core_start(mode, core_start_opts(options))
  end

  defp start_core_transport(mode, %CoreOptions{} = options, core_subscriber) do
    core_start(mode, Keyword.put(core_start_opts(options), :subscriber, core_subscriber))
  end

  defp core_start(:start, opts), do: CoreErlexec.start(opts)
  defp core_start(:start_link, opts), do: CoreErlexec.start_link(opts)

  defp core_start_opts(%CoreOptions{} = options) do
    [
      command: options.command,
      args: options.args,
      cwd: options.cwd,
      env: options.env,
      startup_mode: options.startup_mode,
      task_supervisor: options.task_supervisor,
      event_tag: options.event_tag,
      headless_timeout_ms: options.headless_timeout_ms,
      max_buffer_size: options.max_buffer_size,
      max_stderr_buffer_size: options.max_stderr_buffer_size,
      stderr_callback: options.stderr_callback
    ]
  end

  defp subscribe_proxy(transport, proxy, core_ref) do
    case legacy_reply(CoreErlexec.subscribe(transport, proxy, core_ref)) do
      :ok ->
        :ok

      {:error, {:transport, reason}} ->
        _ = SubscriberProxy.stop(proxy)
        {:error, reason}
    end
  end

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

  defp legacy_reply({:error, {:transport, %CoreTransportError{} = error}}),
    do: {:error, {:transport, legacy_transport_reason(error)}}

  defp legacy_reply({:error, %CoreTransportError{} = error}),
    do: {:error, {:transport, legacy_transport_reason(error)}}

  defp legacy_reply(other), do: other

  defp safe_call(transport, message, timeout \\ @default_call_timeout)

  defp safe_call(transport, message, timeout)
       when is_pid(transport) and is_integer(timeout) and timeout >= 0 do
    with {:ok, task} <-
           AmpSdk.TaskSupport.async_nolink(fn ->
             try do
               {:ok, GenServer.call(transport, message, :infinity)}
             catch
               :exit, {:timeout, _} -> {:error, :timeout}
               :exit, {:noproc, _} -> {:error, :not_connected}
               :exit, :noproc -> {:error, :not_connected}
               :exit, {:normal, _} -> {:error, :not_connected}
               :exit, {:shutdown, _} -> {:error, :not_connected}
               :exit, reason -> {:error, {:call_exit, reason}}
             end
           end) do
      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} -> result
        {:exit, reason} -> {:error, {:call_exit, reason}}
        nil -> {:error, :timeout}
      end
    else
      {:error, :noproc} -> {:error, :not_connected}
      {:error, reason} -> {:error, reason}
    end
  catch
    :exit, {:noproc, _} ->
      {:error, :not_connected}

    :exit, :noproc ->
      {:error, :not_connected}
  end

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

  defp transport_error({:transport, reason}), do: {:error, {:transport, reason}}
  defp transport_error(reason), do: {:error, {:transport, reason}}
end
