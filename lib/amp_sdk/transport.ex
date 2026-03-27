defmodule AmpSdk.Transport do
  @moduledoc """
  Behaviour for the public Amp raw transport surface.

  The shared core owns subprocess lifecycle and raw transport behavior; this
  module defines the Amp-facing surface layered on top.
  """

  alias AmpSdk.Error
  alias CliSubprocessCore.ProcessExit, as: CoreProcessExit
  alias CliSubprocessCore.Transport, as: CoreTransport
  alias CliSubprocessCore.Transport.Error, as: CoreTransportError
  alias CliSubprocessCore.Transport.TaggedRelay

  import Kernel, except: [send: 2]

  @core_event_tag :amp_sdk_core_transport
  @public_event_tag :amp_sdk_transport

  @type t :: pid()
  @type message :: binary()
  @type opts :: keyword()
  @type subscription_tag :: reference()

  @callback start(opts()) :: {:ok, t()} | {:error, term()}
  @callback start_link(opts()) :: {:ok, t()} | {:error, term()}
  @callback send(t(), message()) :: :ok | {:error, term()}
  @callback subscribe(t(), pid(), subscription_tag()) :: :ok | {:error, term()}
  @callback close(t()) :: :ok
  @callback force_close(t()) :: :ok | {:error, term()}
  @callback interrupt(t()) :: :ok | {:error, term()}
  @callback status(t()) :: :connected | :disconnected | :error
  @callback end_input(t()) :: :ok | {:error, term()}
  @callback stderr(t()) :: String.t()

  @spec start(opts()) :: {:ok, t()} | {:error, term()}
  def start(opts) when is_list(opts) do
    start_transport(&CoreTransport.start/1, opts)
  end

  @spec start_link(opts()) :: {:ok, t()} | {:error, term()}
  def start_link(opts) when is_list(opts) do
    start_transport(&CoreTransport.start_link/1, opts)
  end

  @spec send(t(), message()) :: :ok | {:error, term()}
  def send(transport, message) when is_pid(transport) do
    CoreTransport.send(transport, message)
    |> legacy_reply()
  end

  @spec subscribe(t(), pid(), subscription_tag()) :: :ok | {:error, term()}
  def subscribe(transport, pid, tag)
      when is_pid(transport) and is_pid(pid) and is_reference(tag) do
    with {:ok, relay, core_ref} <- start_tagged_relay(pid, tag) do
      case CoreTransport.subscribe(transport, relay, core_ref) |> legacy_reply() do
        :ok ->
          TaggedRelay.attach_transport(relay, transport)
          :ok

        {:error, _reason} = error ->
          _ = TaggedRelay.stop(relay)
          error
      end
    else
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  @spec close(t()) :: :ok
  def close(transport) when is_pid(transport), do: CoreTransport.close(transport)

  @spec force_close(t()) :: :ok | {:error, term()}
  def force_close(transport) when is_pid(transport) do
    CoreTransport.force_close(transport)
    |> legacy_reply()
  end

  @spec interrupt(t()) :: :ok | {:error, term()}
  def interrupt(transport) when is_pid(transport) do
    CoreTransport.interrupt(transport)
    |> legacy_reply()
  end

  @spec status(t()) :: :connected | :disconnected | :error
  def status(transport) when is_pid(transport), do: CoreTransport.status(transport)

  @spec end_input(t()) :: :ok | {:error, term()}
  def end_input(transport) when is_pid(transport) do
    CoreTransport.end_input(transport)
    |> legacy_reply()
  end

  @spec stderr(pid()) :: String.t()
  def stderr(transport) when is_pid(transport), do: CoreTransport.stderr(transport)

  @doc """
  Normalizes low-level transport reasons into the unified `%AmpSdk.Error{}` envelope.
  """
  @spec error_to_error(term(), keyword()) :: Error.t()
  def error_to_error(reason, opts \\ []) do
    Error.normalize(reason, Keyword.put_new(opts, :kind, :transport_error))
  end

  defp start_transport(start_fun, opts) when is_function(start_fun, 1) and is_list(opts) do
    {subscriber, opts} = Keyword.pop(opts, :subscriber)
    normalized_opts = normalize_start_opts(opts)

    with {:ok, subscriber_relay, core_subscriber} <- build_bootstrap_subscriber(subscriber) do
      case maybe_add_subscriber(normalized_opts, core_subscriber)
           |> start_fun.()
           |> legacy_reply() do
        {:ok, transport} ->
          maybe_attach_bootstrap_relay(subscriber_relay, transport)
          {:ok, transport}

        {:error, _reason} = error ->
          maybe_stop_bootstrap_relay(subscriber_relay)
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
    |> Keyword.put_new(:buffer_events_until_subscribe?, true)
    |> Keyword.put_new(:headless_timeout_ms, AmpSdk.Defaults.transport_headless_timeout_ms())
  end

  defp default_task_supervisor do
    case Application.ensure_all_started(:amp_sdk) do
      {:ok, _started_apps} -> AmpSdk.TaskSupervisor
      {:error, _reason} -> CliSubprocessCore.TaskSupervisor
    end
  end

  defp build_bootstrap_subscriber(nil), do: {:ok, nil, nil}

  defp build_bootstrap_subscriber({pid, tag}) when is_pid(pid) and is_reference(tag) do
    with {:ok, relay, core_ref} <- start_tagged_relay(pid, tag) do
      {:ok, relay, {relay, core_ref}}
    end
  end

  defp build_bootstrap_subscriber(subscriber),
    do: {:error, {:invalid_subscriber, subscriber}}

  defp maybe_add_subscriber(opts, nil), do: opts
  defp maybe_add_subscriber(opts, subscriber), do: Keyword.put(opts, :subscriber, subscriber)

  defp maybe_attach_bootstrap_relay(nil, _transport), do: :ok

  defp maybe_attach_bootstrap_relay(relay, transport) when is_pid(relay) and is_pid(transport) do
    TaggedRelay.attach_transport(relay, transport)
  end

  defp maybe_stop_bootstrap_relay(nil), do: :ok
  defp maybe_stop_bootstrap_relay(relay) when is_pid(relay), do: TaggedRelay.stop(relay)

  defp start_tagged_relay(pid, tag) when is_pid(pid) and is_reference(tag) do
    core_ref = make_ref()

    case TaggedRelay.start(pid, tag,
           core_event_tag: @core_event_tag,
           core_ref: core_ref,
           public_event_tag: @public_event_tag,
           event_mapper: &map_core_event/1
         ) do
      {:ok, relay} -> {:ok, relay, core_ref}
      {:error, reason} -> {:error, reason}
    end
  end

  defp map_core_event({:message, line}) when is_binary(line), do: [{:message, line}]

  defp map_core_event({:error, %CoreTransportError{} = error}) do
    [{:error, legacy_transport_reason(error)}]
  end

  defp map_core_event({:stderr, chunk}) when is_binary(chunk), do: [{:stderr, chunk}]

  defp map_core_event({:exit, %CoreProcessExit{} = exit}) do
    [{:exit, exit.reason}]
  end

  defp map_core_event(_event), do: []

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
