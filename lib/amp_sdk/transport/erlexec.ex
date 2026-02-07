defmodule AmpSdk.Transport.Erlexec do
  @moduledoc "Transport implementation backed by erlexec for the Amp CLI."

  use GenServer

  import Kernel, except: [send: 2]

  alias AmpSdk.Exec

  @behaviour AmpSdk.Transport

  @default_max_buffer_size 1_048_576
  @default_call_timeout 5_000
  @max_lines_per_batch 200

  defstruct subprocess: nil,
            subscribers: %{},
            stdout_buffer: "",
            pending_lines: :queue.new(),
            drain_scheduled?: false,
            status: :disconnected,
            stderr_buffer: "",
            max_buffer_size: @default_max_buffer_size,
            overflowed?: false,
            pending_calls: %{},
            finalize_timer_ref: nil,
            task_supervisor: AmpSdk.TaskSupervisor,
            io_supervisor: nil

  @type subscriber_info :: %{monitor_ref: reference(), tag: AmpSdk.Transport.subscription_tag()}

  @impl AmpSdk.Transport
  def start(opts) when is_list(opts) do
    GenServer.start(__MODULE__, opts)
  end

  @impl AmpSdk.Transport
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl AmpSdk.Transport
  def send(transport, message) when is_pid(transport) do
    case safe_call(transport, {:send, message}) do
      {:ok, result} -> result
      {:error, reason} -> transport_error(reason)
    end
  end

  @impl AmpSdk.Transport
  def subscribe(transport, pid) when is_pid(transport) and is_pid(pid) do
    subscribe(transport, pid, :legacy)
  end

  @impl AmpSdk.Transport
  def subscribe(transport, pid, tag)
      when is_pid(transport) and is_pid(pid) and (tag == :legacy or is_reference(tag)) do
    case safe_call(transport, {:subscribe, pid, tag}) do
      {:ok, result} -> result
      {:error, reason} -> transport_error(reason)
    end
  end

  @impl AmpSdk.Transport
  def close(transport) when is_pid(transport) do
    GenServer.stop(transport, :normal)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, :noproc -> :ok
  end

  @impl AmpSdk.Transport
  def end_input(transport) when is_pid(transport) do
    case safe_call(transport, :end_input) do
      {:ok, result} -> result
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

  @spec stderr(pid()) :: String.t()
  def stderr(transport) when is_pid(transport) do
    case safe_call(transport, :stderr) do
      {:ok, stderr} when is_binary(stderr) -> stderr
      _ -> ""
    end
  end

  @impl GenServer
  def init(opts) do
    command = Keyword.fetch!(opts, :command)
    args = Keyword.get(opts, :args, [])
    cwd = Keyword.get(opts, :cwd)
    env = Keyword.get(opts, :env, [])
    task_supervisor = Keyword.get(opts, :task_supervisor, AmpSdk.TaskSupervisor)
    subscriber = Keyword.get(opts, :subscriber)

    with {:ok, io_supervisor} <- Task.Supervisor.start_link(),
         {:ok, state} <-
           start_subprocess(
             command,
             args,
             cwd,
             env,
             subscriber,
             io_supervisor,
             task_supervisor,
             Keyword.get(opts, :max_buffer_size, @default_max_buffer_size)
           ) do
      {:ok, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, pid, tag}, _from, state) do
    {:reply, :ok, put_subscriber(state, pid, tag)}
  end

  def handle_call({:send, message}, from, %{subprocess: {pid, _}} = state) do
    case start_io_task(state, fn -> send_payload(pid, message) end) do
      {:ok, task} ->
        pending_calls = Map.put(state.pending_calls, task.ref, from)
        {:noreply, %{state | pending_calls: pending_calls}}

      {:error, reason} ->
        {:reply, transport_error(reason), state}
    end
  end

  def handle_call({:send, _}, _from, %{subprocess: nil} = state) do
    {:reply, transport_error(:not_connected), state}
  end

  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  def handle_call(:end_input, from, %{subprocess: {pid, _}} = state) do
    case start_io_task(state, fn -> send_eof(pid) end) do
      {:ok, task} ->
        pending_calls = Map.put(state.pending_calls, task.ref, from)
        {:noreply, %{state | pending_calls: pending_calls}}

      {:error, reason} ->
        {:reply, transport_error(reason), state}
    end
  end

  def handle_call(:end_input, _from, %{subprocess: nil} = state) do
    {:reply, transport_error(:not_connected), state}
  end

  def handle_call(:stderr, _from, state) do
    {:reply, state.stderr_buffer, state}
  end

  @impl GenServer
  def handle_info({:stdout, os_pid, data}, %{subprocess: {_pid, os_pid}} = state) do
    data = IO.iodata_to_binary(data)

    state =
      state
      |> append_stdout_data(data)
      |> drain_stdout_lines(@max_lines_per_batch)
      |> maybe_schedule_drain()

    {:noreply, state}
  end

  def handle_info({:stderr, _os_pid, data}, state) do
    data = IO.iodata_to_binary(data)
    {:noreply, %{state | stderr_buffer: state.stderr_buffer <> data}}
  end

  def handle_info({ref, result}, %{pending_calls: pending_calls} = state)
      when is_reference(ref) do
    case Map.pop(pending_calls, ref) do
      {nil, _} ->
        {:noreply, state}

      {from, rest} ->
        Process.demonitor(ref, [:flush])
        GenServer.reply(from, normalize_call_result(result))
        {:noreply, %{state | pending_calls: rest}}
    end
  end

  def handle_info({:DOWN, os_pid, :process, pid, reason}, %{subprocess: {pid, os_pid}} = state) do
    state = cancel_finalize_timer(state)
    timer_ref = Process.send_after(self(), {:finalize_exit, os_pid, pid, reason}, 25)
    {:noreply, %{state | finalize_timer_ref: timer_ref}}
  end

  def handle_info({:finalize_exit, os_pid, pid, reason}, %{subprocess: {pid, os_pid}} = state) do
    state = %{state | finalize_timer_ref: nil}
    state = flush_stdout_buffer(state)

    if state.stderr_buffer != "" do
      send_event(state.subscribers, {:stderr, state.stderr_buffer})
    end

    send_event(state.subscribers, {:exit, reason})
    {:stop, :normal, %{state | status: :disconnected, subprocess: nil}}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, %{pending_calls: pending_calls} = state)
      when is_reference(ref) do
    case Map.pop(pending_calls, ref) do
      {from, rest} when not is_nil(from) ->
        GenServer.reply(from, transport_error({:send_failed, reason}))
        {:noreply, %{state | pending_calls: rest}}

      {nil, _} ->
        handle_subscriber_down(ref, pid, state)
    end
  end

  def handle_info(:drain_stdout, state) do
    state =
      state
      |> Map.put(:drain_scheduled?, false)
      |> drain_stdout_lines(@max_lines_per_batch)
      |> maybe_schedule_drain()

    {:noreply, state}
  end

  def handle_info(_other, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    state = cancel_finalize_timer(state)
    demonitor_subscribers(state.subscribers)
    cleanup_pending_calls(state.pending_calls)
    stop_io_supervisor(state.io_supervisor)

    case state.subprocess do
      {pid, _} ->
        :exec.stop(pid)
        :ok

      _ ->
        :ok
    end
  catch
    _, _ -> :ok
  end

  defp safe_call(transport, message, timeout \\ @default_call_timeout) do
    {:ok, GenServer.call(transport, message, timeout)}
  catch
    :exit, reason ->
      {:error, normalize_call_exit(reason)}
  end

  defp normalize_call_exit({:noproc, _}), do: :not_connected
  defp normalize_call_exit(:noproc), do: :not_connected
  defp normalize_call_exit({:normal, _}), do: :not_connected
  defp normalize_call_exit({:shutdown, _}), do: :not_connected
  defp normalize_call_exit({:timeout, _}), do: :timeout
  defp normalize_call_exit(reason), do: {:call_exit, reason}

  defp add_bootstrap_subscriber(state, nil), do: {:ok, state}

  defp add_bootstrap_subscriber(state, {pid, tag})
       when is_pid(pid) and (tag == :legacy or is_reference(tag)) do
    {:ok, put_subscriber(state, pid, tag)}
  end

  defp add_bootstrap_subscriber(_state, _subscriber), do: {:error, :invalid_subscriber}

  defp start_subprocess(
         command,
         args,
         cwd,
         env,
         subscriber,
         io_supervisor,
         task_supervisor,
         max_buffer_size
       ) do
    state = %__MODULE__{
      max_buffer_size: max_buffer_size,
      task_supervisor: task_supervisor,
      io_supervisor: io_supervisor
    }

    exec_opts =
      [:stdin, :stdout, :stderr, :monitor]
      |> Exec.add_cwd(cwd)
      |> Exec.add_env(env)

    cmd = Exec.build_command(command, args)

    case :exec.run(cmd, exec_opts) do
      {:ok, pid, os_pid} ->
        state = %{state | subprocess: {pid, os_pid}, status: :connected}
        add_bootstrap_subscriber(state, subscriber)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_subscriber(state, pid, tag) do
    subscribers =
      case Map.fetch(state.subscribers, pid) do
        {:ok, %{monitor_ref: monitor_ref}} ->
          Map.put(state.subscribers, pid, %{monitor_ref: monitor_ref, tag: tag})

        :error ->
          monitor_ref = Process.monitor(pid)
          Map.put(state.subscribers, pid, %{monitor_ref: monitor_ref, tag: tag})
      end

    %{state | subscribers: subscribers}
  end

  defp handle_subscriber_down(ref, pid, state) do
    subscribers =
      case Map.pop(state.subscribers, pid) do
        {%{monitor_ref: ^ref}, rest} -> rest
        {_, rest} -> rest
      end

    state = %{state | subscribers: subscribers}

    if map_size(subscribers) == 0 do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  defp start_io_task(state, fun) when is_function(fun, 0) do
    case start_task(state.task_supervisor, fun) do
      {:ok, task} ->
        {:ok, task}

      {:error, :noproc} ->
        start_task(state.io_supervisor, fun)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_task(supervisor, fun) do
    {:ok, Task.Supervisor.async_nolink(supervisor, fun)}
  catch
    :exit, {:noproc, _} ->
      {:error, :noproc}

    :exit, reason ->
      {:error, {:task_start_failed, reason}}
  end

  defp send_payload(pid, message) do
    payload = message |> normalize_payload() |> ensure_newline()
    :exec.send(pid, payload)
    :ok
  catch
    kind, reason ->
      transport_error({:send_failed, {kind, reason}})
  end

  defp send_eof(pid) do
    :exec.send(pid, :eof)
    :ok
  catch
    kind, reason ->
      transport_error({:send_failed, {kind, reason}})
  end

  defp normalize_call_result(:ok), do: :ok
  defp normalize_call_result({:error, {:transport, _reason}} = error), do: error
  defp normalize_call_result({:error, reason}), do: transport_error(reason)
  defp normalize_call_result(other), do: transport_error({:unexpected_task_result, other})

  defp send_event(subscribers, event) do
    Enum.each(subscribers, fn {pid, info} ->
      dispatch_event(pid, info, event)
    end)
  end

  defp dispatch_event(pid, %{tag: :legacy}, {:message, line}),
    do: Kernel.send(pid, {:transport_message, line})

  defp dispatch_event(pid, %{tag: :legacy}, {:error, reason}),
    do: Kernel.send(pid, {:transport_error, reason})

  defp dispatch_event(pid, %{tag: :legacy}, {:stderr, data}),
    do: Kernel.send(pid, {:transport_stderr, data})

  defp dispatch_event(pid, %{tag: :legacy}, {:exit, reason}),
    do: Kernel.send(pid, {:transport_exit, reason})

  defp dispatch_event(pid, %{tag: ref}, event) when is_reference(ref),
    do: Kernel.send(pid, {:amp_sdk_transport, ref, event})

  defp append_stdout_data(%{overflowed?: true} = state, data) do
    case String.split(data, "\n", parts: 2) do
      [_single] ->
        state

      [_dropped, rest] ->
        state
        |> Map.put(:overflowed?, false)
        |> Map.put(:stdout_buffer, "")
        |> append_stdout_data(rest)
    end
  end

  defp append_stdout_data(state, data) do
    full = state.stdout_buffer <> data
    {complete_lines, remaining} = split_complete_lines(full)

    pending_lines =
      Enum.reduce(complete_lines, state.pending_lines, fn line, queue ->
        :queue.in(line, queue)
      end)

    state = %{state | pending_lines: pending_lines, stdout_buffer: "", overflowed?: false}

    if byte_size(remaining) > state.max_buffer_size do
      send_event(state.subscribers, {:error, {:buffer_overflow, byte_size(remaining)}})
      %{state | stdout_buffer: "", overflowed?: true}
    else
      %{state | stdout_buffer: remaining}
    end
  end

  defp drain_stdout_lines(state, 0), do: state

  defp drain_stdout_lines(state, remaining) when is_integer(remaining) and remaining > 0 do
    case :queue.out(state.pending_lines) do
      {:empty, _queue} ->
        state

      {{:value, line}, queue} ->
        state = %{state | pending_lines: queue}

        if byte_size(line) > state.max_buffer_size do
          send_event(state.subscribers, {:error, {:buffer_overflow, byte_size(line)}})
        else
          send_event(state.subscribers, {:message, line})
        end

        drain_stdout_lines(state, remaining - 1)
    end
  end

  defp drain_stdout_lines_all(state) do
    case :queue.out(state.pending_lines) do
      {:empty, _queue} ->
        state

      {{:value, line}, queue} ->
        state = %{state | pending_lines: queue}

        if byte_size(line) > state.max_buffer_size do
          send_event(state.subscribers, {:error, {:buffer_overflow, byte_size(line)}})
        else
          send_event(state.subscribers, {:message, line})
        end

        drain_stdout_lines_all(state)
    end
  end

  defp maybe_schedule_drain(%{drain_scheduled?: true} = state), do: state

  defp maybe_schedule_drain(state) do
    if :queue.is_empty(state.pending_lines) do
      state
    else
      Kernel.send(self(), :drain_stdout)
      %{state | drain_scheduled?: true}
    end
  end

  defp split_complete_lines(""), do: {[], ""}

  defp split_complete_lines(data) do
    lines = String.split(data, "\n")

    case List.pop_at(lines, -1) do
      {nil, _} -> {[], ""}
      {"", rest} -> {rest, ""}
      {last, rest} -> {rest, last}
    end
  end

  defp flush_stdout_buffer(state) do
    state = drain_stdout_lines_all(state)
    line = String.trim(state.stdout_buffer)

    cond do
      line == "" ->
        %{state | stdout_buffer: "", overflowed?: false, drain_scheduled?: false}

      byte_size(line) > state.max_buffer_size ->
        send_event(state.subscribers, {:error, {:buffer_overflow, byte_size(line)}})
        %{state | stdout_buffer: "", overflowed?: false, drain_scheduled?: false}

      true ->
        send_event(state.subscribers, {:message, line})
        %{state | stdout_buffer: "", overflowed?: false, drain_scheduled?: false}
    end
  end

  defp cancel_finalize_timer(%{finalize_timer_ref: nil} = state), do: state

  defp cancel_finalize_timer(state) do
    _ = Process.cancel_timer(state.finalize_timer_ref, async: false, info: false)
    flush_finalize_message(state.subprocess)
    %{state | finalize_timer_ref: nil}
  end

  defp flush_finalize_message({pid, os_pid}) do
    receive do
      {:finalize_exit, ^os_pid, ^pid, _reason} -> :ok
    after
      0 -> :ok
    end
  end

  defp flush_finalize_message(_), do: :ok

  defp cleanup_pending_calls(pending_calls) do
    Enum.each(pending_calls, fn {ref, from} ->
      Process.demonitor(ref, [:flush])
      GenServer.reply(from, transport_error(:transport_stopped))
    end)
  end

  defp demonitor_subscribers(subscribers) do
    Enum.each(subscribers, fn {_pid, %{monitor_ref: ref}} ->
      Process.demonitor(ref, [:flush])
    end)
  end

  defp stop_io_supervisor(nil), do: :ok
  defp stop_io_supervisor(pid) when is_pid(pid), do: Process.exit(pid, :normal)

  defp normalize_payload(message) when is_binary(message), do: message

  defp normalize_payload(message) when is_map(message) or is_list(message),
    do: Jason.encode!(message)

  defp normalize_payload(message), do: to_string(message)

  defp ensure_newline(payload) do
    if String.ends_with?(payload, "\n"), do: payload, else: payload <> "\n"
  end

  defp transport_error(reason), do: {:error, {:transport, reason}}
end
