defmodule AmpSdk.Stream do
  @moduledoc "Manages streaming execution of the Amp CLI."

  alias AmpSdk.{CLI, Env, Error, Types}
  alias AmpSdk.Transport.Erlexec
  alias AmpSdk.Types.Options

  @transport_close_grace_ms 2_000

  @type execute_input :: String.t() | [Types.UserInputMessage.t() | map()]

  defmodule State do
    @moduledoc false

    @enforce_keys [:transport, :transport_ref, :receive_timeout_ms]
    defstruct transport: nil,
              transport_ref: nil,
              done?: false,
              received_result?: false,
              temp_dir: nil,
              stderr: "",
              receive_timeout_ms: 300_000

    @type t :: %__MODULE__{
            transport: pid(),
            transport_ref: reference(),
            done?: boolean(),
            received_result?: boolean(),
            temp_dir: String.t() | nil,
            stderr: String.t(),
            receive_timeout_ms: pos_integer()
          }
  end

  @spec execute(execute_input(), Options.t()) :: Enumerable.t(Types.stream_message())
  def execute(input, %Options{} = options \\ %Options{})
      when is_binary(input) or is_list(input) do
    Stream.resource(
      fn -> start(input, options) end,
      &receive_next/1,
      &cleanup/1
    )
  end

  defp start(input, %Options{} = options) do
    input_mode = input_mode(input)

    try do
      with {:ok, command} <- CLI.resolve(),
           {:ok, args} <- {:ok, build_args(options, input_mode)},
           {:ok, settings_path, temp_dir} <- build_settings_file(options) do
        args = maybe_add_settings(args, settings_path)
        full_args = CLI.command_args(command, args)
        env = build_env(options)
        cwd = options.cwd || File.cwd!()
        transport_ref = make_ref()

        case Erlexec.start(
               command: command.program,
               args: full_args,
               cwd: cwd,
               env: Enum.to_list(env),
               subscriber: {self(), transport_ref}
             ) do
          {:ok, transport} ->
            case send_initial_input(transport, input) do
              :ok ->
                %State{
                  transport: transport,
                  transport_ref: transport_ref,
                  temp_dir: temp_dir,
                  receive_timeout_ms: options.stream_timeout_ms
                }

              {:error, reason} ->
                cleanup_start_resources(transport, temp_dir)
                {:error, Error.normalize(reason, kind: :stream_start_failed)}
            end

          {:error, reason} ->
            cleanup_temp_dir(temp_dir)
            {:error, Error.normalize(reason, kind: :stream_start_failed)}
        end
      else
        {:error, reason} ->
          {:error, Error.normalize(reason, kind: :stream_start_failed)}
      end
    rescue
      error ->
        {:error, Error.normalize(error, kind: :stream_start_failed)}
    catch
      :exit, reason ->
        {:error, Error.normalize(reason, kind: :stream_start_failed)}
    end
  end

  defp input_mode(input) when is_binary(input), do: :prompt
  defp input_mode(input) when is_list(input), do: :json_input

  defp send_initial_input(transport, input) do
    send_input(transport, input)
  catch
    :exit, reason ->
      {:error, {:transport_call_exit, reason}}
  end

  defp cleanup_start_resources(transport, temp_dir) do
    safe_close(transport)
    cleanup_temp_dir(temp_dir)
  end

  defp send_input(transport, prompt) when is_binary(prompt) do
    with :ok <- Erlexec.send(transport, prompt),
         :ok <- Erlexec.end_input(transport) do
      :ok
    end
  end

  defp send_input(_transport, []), do: {:error, :empty_input_messages}

  defp send_input(transport, messages) when is_list(messages) do
    with :ok <- send_messages(transport, messages),
         :ok <- Erlexec.end_input(transport) do
      :ok
    end
  end

  defp send_messages(transport, messages) do
    Enum.reduce_while(messages, :ok, fn message, _acc ->
      case Erlexec.send(transport, message) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp receive_next({:error, reason}) do
    error_msg = %AmpSdk.Types.ErrorResultMessage{
      error: "Failed to start: #{Error.message(reason)}",
      is_error: true
    }

    {[error_msg], {:halted}}
  end

  defp receive_next({:halted}), do: {:halt, {:halted}}
  defp receive_next(%State{done?: true} = state), do: {:halt, state}

  defp receive_next(%State{} = state) do
    receive do
      {:amp_sdk_transport, ref, {:message, line}}
      when ref == state.transport_ref and is_binary(line) ->
        handle_line(line, state)

      {:amp_sdk_transport, ref, {:error, error}} when ref == state.transport_ref ->
        normalized = Error.normalize(error, kind: :transport_error)

        error_msg = %AmpSdk.Types.ErrorResultMessage{
          error: "Transport error: #{normalized.message}",
          is_error: true
        }

        {[error_msg], mark_done(state)}

      {:amp_sdk_transport, ref, {:stderr, data}}
      when ref == state.transport_ref and is_binary(data) ->
        receive_next(append_stderr(state, data))

      {:amp_sdk_transport, ref, {:exit, reason}} when ref == state.transport_ref ->
        handle_transport_exit(reason, state)
    after
      state.receive_timeout_ms ->
        timeout_error = %AmpSdk.Types.ErrorResultMessage{
          error: "Timed out after #{state.receive_timeout_ms}ms waiting for CLI output",
          is_error: true
        }

        {[timeout_error], mark_done(state)}
    end
  end

  defp handle_transport_exit(_reason, %State{received_result?: true} = state) do
    {:halt, mark_done(state)}
  end

  defp handle_transport_exit(reason, %State{} = state) do
    error_text =
      cond do
        String.trim(state.stderr) != "" ->
          String.trim(state.stderr)

        reason == :normal ->
          "CLI process exited without producing output"

        true ->
          "CLI process exited: #{inspect(reason)}"
      end

    error_msg = %AmpSdk.Types.ErrorResultMessage{
      error: error_text,
      is_error: true
    }

    {[error_msg], mark_done(state)}
  end

  defp handle_line(line, %State{} = state) do
    case Types.parse_stream_message(line) do
      {:ok, message} ->
        state =
          if Types.final_message?(message),
            do: mark_result_received(state),
            else: state

        {[message], state}

      {:error, reason} ->
        normalized = Error.normalize(reason, kind: :parse_error)

        error_msg = %AmpSdk.Types.ErrorResultMessage{
          error: "JSON parse error: #{normalized.message}",
          is_error: true
        }

        {[error_msg], mark_done(state)}
    end
  end

  defp append_stderr(%State{} = state, data), do: %{state | stderr: state.stderr <> data}
  defp mark_done(%State{} = state), do: %{state | done?: true}
  defp mark_result_received(%State{} = state), do: %{state | received_result?: true, done?: true}

  defp cleanup(%State{transport: transport, temp_dir: temp_dir}) do
    close_transport_with_timeout(transport, @transport_close_grace_ms)
    cleanup_temp_dir(temp_dir)
    :ok
  end

  defp cleanup(_), do: :ok

  defp close_transport_with_timeout(transport, timeout_ms) when is_pid(transport) do
    ref = Process.monitor(transport)
    safe_force_close(transport)

    receive do
      {:DOWN, ^ref, :process, ^transport, _reason} ->
        :ok
    after
      timeout_ms ->
        safe_force_close(transport)
        safe_kill(transport)
        await_down_or_demonitor(ref, transport, 250)
    end
  end

  defp await_down_or_demonitor(ref, transport, timeout_ms) do
    receive do
      {:DOWN, ^ref, :process, ^transport, _reason} ->
        :ok
    after
      timeout_ms ->
        Process.demonitor(ref, [:flush])
        :ok
    end
  end

  defp safe_close(transport) when is_pid(transport) do
    Erlexec.close(transport)
  catch
    :exit, _ -> :ok
  end

  defp safe_force_close(transport) when is_pid(transport) do
    Erlexec.force_close(transport)
  catch
    :exit, _ -> :ok
  end

  defp safe_kill(transport) when is_pid(transport) do
    Process.exit(transport, :kill)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp cleanup_temp_dir(nil), do: :ok

  defp cleanup_temp_dir(dir) do
    File.rm_rf(dir)
  rescue
    _ -> :ok
  end

  @spec build_args(Options.t()) :: [String.t()]
  def build_args(%Options{} = options) do
    build_args(options, :prompt)
  end

  @spec build_args(Options.t(), :prompt | :json_input) :: [String.t()]
  def build_args(%Options{} = options, input_mode) do
    []
    |> add_thread_args(options)
    |> add_stream_format(options, input_mode)
    |> add_simple_flags(options)
    |> add_mcp_config(options)
    |> add_labels(options)
    |> add_boolean_flags(options)
  end

  defp add_thread_args(args, %Options{continue_thread: true}),
    do: args ++ ["threads", "continue"]

  defp add_thread_args(args, %Options{continue_thread: id}) when is_binary(id),
    do: args ++ ["threads", "continue", id]

  defp add_thread_args(args, _options), do: args

  defp add_stream_format(args, %Options{thinking: true}, :prompt),
    do: args ++ ["--execute", "--stream-json-thinking"]

  defp add_stream_format(args, _options, :prompt),
    do: args ++ ["--execute", "--stream-json"]

  defp add_stream_format(args, _options, :json_input),
    do: args ++ ["--execute", "--stream-json-input"]

  defp add_simple_flags(args, options) do
    args
    |> maybe_append(options.dangerously_allow_all, ["--dangerously-allow-all"])
    |> maybe_append(options.visibility, ["--visibility", options.visibility])
    |> maybe_append(options.log_level, ["--log-level", options.log_level])
    |> maybe_append(options.log_file, ["--log-file", options.log_file])
    |> maybe_append(options.mode, ["--mode", options.mode])
  end

  defp add_mcp_config(args, %Options{mcp_config: nil}), do: args

  defp add_mcp_config(args, %Options{mcp_config: config}) when is_binary(config),
    do: args ++ ["--mcp-config", config]

  defp add_mcp_config(args, %Options{mcp_config: config}),
    do: args ++ ["--mcp-config", Jason.encode!(config)]

  defp add_labels(args, %Options{labels: nil}), do: args

  defp add_labels(args, %Options{labels: labels}),
    do: Enum.reduce(labels, args, fn label, acc -> acc ++ ["--label", label] end)

  defp add_boolean_flags(args, options) do
    args = if options.no_ide, do: args ++ ["--no-ide"], else: args
    args = if options.no_notifications, do: args ++ ["--no-notifications"], else: args
    args = if options.no_color, do: args ++ ["--no-color"], else: args
    if options.no_jetbrains, do: args ++ ["--no-jetbrains"], else: args
  end

  defp maybe_append(args, nil, _extra), do: args
  defp maybe_append(args, false, _extra), do: args
  defp maybe_append(args, _truthy, extra), do: args ++ extra

  @doc false
  @spec build_settings_file(Options.t()) ::
          {:ok, String.t() | nil, String.t() | nil} | {:error, Error.t()}
  def build_settings_file(%Options{permissions: nil, skills: nil}) do
    {:ok, nil, nil}
  end

  def build_settings_file(%Options{} = options) do
    with {:ok, merged} <- read_base_settings(options.settings_file) do
      merged =
        if options.permissions do
          perms = Enum.map(options.permissions, &encode_permission/1)
          Map.put(merged, "amp.permissions", perms)
        else
          merged
        end

      merged =
        if options.skills do
          Map.put(merged, "amp.skills.path", options.skills)
        else
          merged
        end

      write_settings_file(merged)
    end
  end

  defp write_settings_file(merged) do
    case create_temp_dir() do
      {:ok, temp_dir} ->
        case persist_settings_file(merged, temp_dir) do
          {:ok, settings_path} ->
            {:ok, settings_path, temp_dir}

          {:error, %Error{} = error} ->
            cleanup_temp_dir(temp_dir)
            {:error, error}
        end

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp persist_settings_file(merged, temp_dir) do
    settings_path = Path.join(temp_dir, "settings.json")

    with {:ok, encoded} <- encode_settings(merged),
         :ok <- write_settings(settings_path, encoded) do
      {:ok, settings_path}
    end
  end

  defp encode_settings(merged) do
    case Jason.encode(merged, pretty: true) do
      {:ok, encoded} ->
        {:ok, encoded}

      {:error, reason} ->
        {:error,
         Error.new(:invalid_configuration, "Failed to encode temporary settings", cause: reason)}
    end
  end

  defp write_settings(settings_path, encoded) do
    case File.write(settings_path, encoded) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error,
         Error.new(:invalid_configuration, "Failed to write temporary settings file",
           cause: reason,
           context: %{path: settings_path}
         )}
    end
  end

  defp encode_permission(%AmpSdk.Types.Permission{} = p) do
    p
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp encode_permission(other), do: other

  defp create_temp_dir do
    System.tmp_dir!()
    |> attempt_create_temp_dir(0)
  end

  defp attempt_create_temp_dir(_base_dir, attempts) when attempts >= 10 do
    {:error, Error.new(:invalid_configuration, "Failed to create temporary settings directory")}
  end

  defp attempt_create_temp_dir(base_dir, attempts) do
    suffix = Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
    dir = Path.join(base_dir, "amp-#{suffix}")

    case File.mkdir(dir) do
      :ok ->
        {:ok, dir}

      {:error, :eexist} ->
        attempt_create_temp_dir(base_dir, attempts + 1)

      {:error, reason} ->
        {:error,
         Error.new(:invalid_configuration, "Failed to create temporary settings directory",
           cause: reason,
           context: %{dir: dir}
         )}
    end
  end

  defp read_base_settings(nil), do: {:ok, %{}}

  defp read_base_settings(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            {:ok, data}

          {:error, reason} ->
            {:error,
             Error.new(:invalid_configuration, "Invalid JSON in settings file",
               cause: reason,
               context: %{path: path}
             )}
        end

      {:error, reason} ->
        {:error,
         Error.new(:invalid_configuration, "Failed to read settings file",
           cause: reason,
           context: %{path: path}
         )}
    end
  end

  defp maybe_add_settings(args, nil), do: args
  defp maybe_add_settings(args, path), do: args ++ ["--settings-file", path]

  @doc false
  @spec build_env(Options.t()) :: map()
  def build_env(%Options{env: env, toolbox: toolbox}) do
    Env.build_cli_env(env || %{}, toolbox: toolbox)
  end
end
