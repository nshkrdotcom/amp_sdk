defmodule AmpSdk.Runtime.CLI do
  @moduledoc """
  Session-oriented runtime kit for the shared Amp CLI lane.

  The tagged mailbox event atom is adapter detail. Higher-level callers should
  consume `AmpSdk.Stream` or projected `AmpSdk.Types.*` messages instead of
  treating the underlying session tag as core identity.
  """

  alias AmpSdk.{CLI, Env, Error, Types, Util}
  alias AmpSdk.Types.Options
  alias CliSubprocessCore.CommandSpec
  alias CliSubprocessCore.Event, as: CoreEvent
  alias CliSubprocessCore.ExecutionSurface
  alias CliSubprocessCore.Payload
  alias CliSubprocessCore.ProcessExit, as: CoreProcessExit
  alias CliSubprocessCore.ProviderProfiles.Amp, as: CoreAmp
  alias CliSubprocessCore.Session
  alias CliSubprocessCore.Transport.Error, as: CoreTransportError

  @runtime_metadata %{lane: :amp_sdk}
  @default_session_event_tag :amp_sdk_runtime_cli

  @type execute_input :: String.t() | [Types.UserInputMessage.t() | map()]

  defmodule ProjectionState do
    @moduledoc false

    defstruct cwd: nil,
              provider_session_id: nil,
              system_emitted?: false,
              result_received?: false,
              assistant_text: "",
              pending_delta: "",
              last_model: nil

    @type t :: %__MODULE__{
            cwd: String.t() | nil,
            provider_session_id: String.t() | nil,
            system_emitted?: boolean(),
            result_received?: boolean(),
            assistant_text: String.t(),
            pending_delta: String.t(),
            last_model: String.t() | nil
          }
  end

  defmodule Profile do
    @moduledoc false

    @behaviour CliSubprocessCore.ProviderProfile

    alias AmpSdk.Runtime.CLI
    alias CliSubprocessCore.ProviderProfiles.Amp, as: CoreAmp

    @impl true
    def id, do: :amp

    @impl true
    def capabilities, do: CoreAmp.capabilities()

    @impl true
    def build_invocation(opts) when is_list(opts), do: CLI.build_invocation(opts)

    @impl true
    def init_parser_state(opts), do: CoreAmp.init_parser_state(opts)

    @impl true
    def decode_stdout(line, state), do: CoreAmp.decode_stdout(line, state)

    @impl true
    def decode_stderr(chunk, state), do: CoreAmp.decode_stderr(chunk, state)

    @impl true
    def handle_exit(reason, state), do: CoreAmp.handle_exit(reason, state)

    @impl true
    def transport_options(opts) when is_list(opts) do
      close_stdin_on_start? = Keyword.get(opts, :input_mode, :prompt) == :prompt

      CoreAmp.transport_options(opts)
      |> Keyword.put(:close_stdin_on_start?, close_stdin_on_start?)
    end
  end

  @type start_option ::
          {:input, execute_input()}
          | {:options, Options.t()}
          | {:subscriber, pid() | {pid(), reference() | :legacy}}
          | {:metadata, map()}
          | {:session_event_tag, atom()}

  @spec start_session([start_option()]) ::
          {:ok, pid(), %{info: map(), projection_state: map(), temp_dir: String.t() | nil}}
          | {:error, term()}
  def start_session(opts) when is_list(opts) do
    input = Keyword.fetch!(opts, :input)
    options = opts |> Keyword.get(:options, %Options{}) |> Options.validate!()
    input_mode = input_mode(input)

    with {:ok, %CommandSpec{} = command_spec} <- CLI.resolve(options.execution_surface),
         {:ok, settings_path, temp_dir} <- build_settings_file(options) do
      session_opts =
        build_session_options(
          input,
          input_mode,
          options,
          command_spec,
          settings_path,
          Keyword.take(opts, [:subscriber, :metadata, :session_event_tag])
        )

      case Session.start_session(session_opts) do
        {:ok, session, info} ->
          {:ok, session,
           %{
             info: info,
             projection_state: new_projection_state(info),
             temp_dir: temp_dir
           }}

        {:error, reason} ->
          cleanup_temp_dir(temp_dir)
          {:error, reason}
      end
    end
  rescue
    error in [ArgumentError] ->
      {:error, error}
  catch
    :exit, reason ->
      {:error, reason}
  end

  @spec subscribe(pid(), pid(), reference()) :: :ok | {:error, term()}
  def subscribe(session, pid, ref) when is_pid(session) and is_pid(pid) and is_reference(ref) do
    Session.subscribe(session, pid, ref)
  end

  @spec send_input(pid(), execute_input(), keyword()) :: :ok | {:error, term()}
  def send_input(session, input, opts \\ [])

  def send_input(session, input, opts) when is_pid(session) and is_binary(input) do
    Session.send_input(session, input, opts)
  end

  def send_input(_session, [], _opts), do: {:error, :empty_input_messages}

  def send_input(session, messages, opts) when is_pid(session) and is_list(messages) do
    Enum.reduce_while(messages, :ok, fn message, _acc ->
      case Session.send_input(session, message, opts) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @spec end_input(pid()) :: :ok | {:error, term()}
  def end_input(session) when is_pid(session), do: Session.end_input(session)

  @spec interrupt(pid()) :: :ok | {:error, term()}
  def interrupt(session) when is_pid(session), do: Session.interrupt(session)

  @spec close(pid()) :: :ok
  def close(session) when is_pid(session), do: Session.close(session)

  @spec info(pid()) :: map()
  def info(session) when is_pid(session), do: Session.info(session)

  @spec capabilities() :: [atom()]
  def capabilities, do: CoreAmp.capabilities()

  @doc false
  @spec session_event_tag() :: atom()
  def session_event_tag, do: @default_session_event_tag

  @spec new_projection_state(map()) :: map()
  def new_projection_state(info \\ %{}) when is_map(info) do
    cwd =
      case Map.get(info, :invocation) do
        %{cwd: value} -> value
        %{"cwd" => value} -> value
        _other -> nil
      end

    %ProjectionState{cwd: cwd}
  end

  @spec project_event(CoreEvent.t(), map()) :: {[Types.stream_message()], map()}
  def project_event(%CoreEvent{kind: :run_started}, %ProjectionState{} = state), do: {[], state}
  def project_event(%CoreEvent{kind: :stderr}, %ProjectionState{} = state), do: {[], state}

  def project_event(
        %CoreEvent{kind: :assistant_delta, payload: %Payload.AssistantDelta{} = payload} = event,
        %ProjectionState{} = state
      ) do
    {prefix, state} = maybe_emit_system_message(event, state)
    session_id = session_id(event, state)

    state = %{
      state
      | provider_session_id: session_id,
        assistant_text: state.assistant_text <> payload.content,
        pending_delta: state.pending_delta <> payload.content
    }

    message =
      assistant_message!(
        session_id,
        [%{"type" => "text", "text" => payload.content}],
        state.last_model
      )

    {prefix ++ [message], state}
  end

  def project_event(
        %CoreEvent{kind: :assistant_message, payload: %Payload.AssistantMessage{} = payload} =
          event,
        %ProjectionState{} = state
      ) do
    {prefix, state} = maybe_emit_system_message(event, state)
    session_id = session_id(event, state)
    content = normalize_assistant_content(payload.content)
    combined_text = extract_text_content(content)
    pending_delta = state.pending_delta

    state = %{
      state
      | provider_session_id: session_id,
        assistant_text: if(combined_text == "", do: state.assistant_text, else: combined_text),
        pending_delta: "",
        last_model: payload.model || state.last_model
    }

    if content == [%{"type" => "text", "text" => pending_delta}] and pending_delta != "" do
      {prefix, state}
    else
      {prefix ++ [assistant_message!(session_id, content, payload.model || state.last_model)],
       state}
    end
  end

  def project_event(
        %CoreEvent{kind: :thinking, payload: %Payload.Thinking{} = payload} = event,
        %ProjectionState{} = state
      ) do
    {prefix, state} = maybe_emit_system_message(event, state)
    session_id = session_id(event, state)

    message =
      assistant_message!(
        session_id,
        [%{"type" => "thinking", "thinking" => payload.content}],
        state.last_model
      )

    {prefix ++ [message], %{state | provider_session_id: session_id}}
  end

  def project_event(
        %CoreEvent{kind: :tool_use, payload: %Payload.ToolUse{} = payload} = event,
        %ProjectionState{} = state
      ) do
    {prefix, state} = maybe_emit_system_message(event, state)
    session_id = session_id(event, state)

    message =
      assistant_message!(
        session_id,
        [
          %{
            "type" => "tool_use",
            "id" => payload.tool_call_id,
            "name" => payload.tool_name,
            "input" => payload.input || %{}
          }
        ],
        state.last_model
      )

    {prefix ++ [message], %{state | provider_session_id: session_id}}
  end

  def project_event(
        %CoreEvent{kind: :tool_result, payload: %Payload.ToolResult{} = payload} = event,
        %ProjectionState{} = state
      ) do
    {prefix, state} = maybe_emit_system_message(event, state)
    session_id = session_id(event, state)

    message =
      user_message!(
        session_id,
        [
          %{
            "type" => "tool_result",
            "tool_use_id" => payload.tool_call_id,
            "content" => stringify_content(payload.content),
            "is_error" => payload.is_error
          }
        ]
      )

    {prefix ++ [message], %{state | provider_session_id: session_id}}
  end

  def project_event(
        %CoreEvent{kind: :user_message, payload: %Payload.UserMessage{} = payload} = event,
        %ProjectionState{} = state
      ) do
    {prefix, state} = maybe_emit_system_message(event, state)
    session_id = session_id(event, state)

    message =
      user_message!(
        session_id,
        Enum.map(payload.content, fn
          value when is_binary(value) -> %{"type" => "text", "text" => value}
          value -> stringify_keys(value)
        end)
      )

    {prefix ++ [message], %{state | provider_session_id: session_id}}
  end

  def project_event(
        %CoreEvent{kind: :result, payload: %Payload.Result{} = payload, raw: raw} = event,
        %ProjectionState{} = state
      ) do
    {prefix, state} = maybe_emit_system_message(event, state)
    session_id = session_id(event, state)

    state = %{
      state
      | provider_session_id: choose_session_id(session_id, state.provider_session_id)
    }

    raw = normalize_raw_map(raw)
    usage = usage_from_result(payload, raw)

    message =
      if truthy?(Map.get(raw, "is_error")) do
        error_result!(%{
          "type" => "result",
          "subtype" => Map.get(raw, "subtype", "error_during_execution"),
          "session_id" => session_id,
          "is_error" => true,
          "error" => Map.get(raw, "error", "Amp execution failed"),
          "kind" => normalize_error_kind(Map.get(raw, "kind")),
          "details" => Map.get(raw, "details"),
          "exit_code" => integer_value(Map.get(raw, "exit_code")),
          "stderr" => Map.get(raw, "stderr"),
          "stderr_truncated?" => truthy?(Map.get(raw, "stderr_truncated?")),
          "duration_ms" => duration_ms(payload, raw),
          "num_turns" => num_turns(raw),
          "usage" => usage,
          "permission_denials" => Map.get(raw, "permission_denials")
        })
      else
        result_message!(%{
          "type" => "result",
          "subtype" => "success",
          "session_id" => session_id,
          "is_error" => false,
          "result" => Map.get(raw, "result", state.assistant_text),
          "duration_ms" => duration_ms(payload, raw),
          "num_turns" => num_turns(raw),
          "usage" => usage
        })
      end

    {prefix ++ [message], %{state | provider_session_id: session_id, result_received?: true}}
  end

  def project_event(
        %CoreEvent{kind: :error, payload: %Payload.Error{} = payload, raw: raw} = event,
        %ProjectionState{} = state
      ) do
    {prefix, state} = maybe_emit_system_message(event, state)
    session_id = session_id(event, state)

    state = %{
      state
      | provider_session_id: choose_session_id(session_id, state.provider_session_id)
    }

    error =
      error_message!(
        payload,
        raw,
        session_id,
        state
      )

    {prefix ++ [error],
     %{
       state
       | provider_session_id: session_id,
         result_received?: true
     }}
  end

  def project_event(_event, %ProjectionState{} = state), do: {[], state}

  @spec stderr_chunk(CoreEvent.t()) :: String.t() | nil
  def stderr_chunk(%CoreEvent{kind: :stderr, payload: %Payload.Stderr{content: content}})
      when is_binary(content),
      do: content

  def stderr_chunk(_event), do: nil

  @spec build_invocation(keyword()) :: {:ok, CliSubprocessCore.Command.t()} | {:error, term()}
  def build_invocation(opts) when is_list(opts) do
    input_mode = Keyword.get(opts, :input_mode, :prompt)

    case Keyword.get(opts, :command_spec) do
      %CommandSpec{} = command_spec when input_mode in [:prompt, :json_input] ->
        options = options_from_provider_opts(opts)

        with {:ok, args} <- build_invocation_args(options, input_mode, opts) do
          args = maybe_add_settings(args, Keyword.get(opts, :settings_path))

          {:ok,
           CliSubprocessCore.Command.new(
             command_spec.program,
             CLI.command_args(command_spec, args),
             cwd: default_cwd(Keyword.get(opts, :cwd), Keyword.get(opts, :execution_surface)),
             env: Keyword.get(opts, :env, %{})
           )}
        end

      %CommandSpec{} ->
        {:error, {:invalid_input_mode, input_mode}}

      _other ->
        {:error, {:missing_option, :command_spec}}
    end
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

  @doc false
  @spec build_env(Options.t()) :: map()
  def build_env(%Options{env: env, toolbox: toolbox}) do
    Env.build_cli_env(env || %{}, toolbox: toolbox)
  end

  defp build_session_options(
         input,
         input_mode,
         %Options{} = options,
         %CommandSpec{} = command_spec,
         settings_path,
         runtime_opts
       ) do
    metadata =
      @runtime_metadata
      |> Map.merge(Keyword.get(runtime_opts, :metadata, %{}))

    [
      provider: :amp,
      profile: Profile,
      subscriber: Keyword.get(runtime_opts, :subscriber),
      metadata: metadata,
      session_event_tag:
        Keyword.get(runtime_opts, :session_event_tag, @default_session_event_tag),
      command_spec: command_spec,
      input_mode: input_mode,
      model_payload: options.model_payload,
      mode: options.mode,
      dangerously_allow_all: options.dangerously_allow_all,
      visibility: options.visibility,
      log_level: options.log_level,
      log_file: options.log_file,
      continue_thread: options.continue_thread,
      mcp_config: options.mcp_config,
      labels: options.labels,
      thinking: options.thinking,
      settings_path: settings_path,
      cwd: default_cwd(options.cwd, options.execution_surface),
      env: build_env(options),
      headless_timeout_ms: :infinity,
      max_stderr_buffer_size: options.max_stderr_buffer_bytes,
      permissions: options.permissions,
      skills: options.skills,
      no_ide: options.no_ide,
      no_notifications: options.no_notifications,
      no_color: options.no_color,
      no_jetbrains: options.no_jetbrains
    ]
    |> maybe_put_prompt(input_mode, input)
    |> Keyword.merge(Options.execution_surface_opts(options))
  end

  defp default_cwd(cwd, _execution_surface) when is_binary(cwd) and cwd != "", do: cwd

  defp default_cwd(_cwd, execution_surface) do
    if ExecutionSurface.remote_surface?(execution_surface), do: nil, else: File.cwd!()
  end

  defp build_invocation_args(%Options{} = options, input_mode, opts) do
    with {:ok, args} <- maybe_embed_prompt(build_args(options, input_mode), input_mode, opts) do
      {:ok, args}
    end
  end

  defp maybe_embed_prompt(args, :json_input, _opts), do: {:ok, args}

  defp maybe_embed_prompt(args, :prompt, opts) do
    case Keyword.get(opts, :prompt) do
      prompt when is_binary(prompt) and prompt != "" ->
        {:ok, inject_execute_prompt(args, prompt)}

      _other ->
        {:error, {:missing_option, :prompt}}
    end
  end

  defp inject_execute_prompt(["--execute" | rest], prompt), do: ["--execute", prompt | rest]

  defp inject_execute_prompt([arg | rest], prompt),
    do: [arg | inject_execute_prompt(rest, prompt)]

  defp inject_execute_prompt([], _prompt), do: raise(ArgumentError, "missing --execute flag")

  defp maybe_put_prompt(opts, :prompt, prompt) when is_binary(prompt) and prompt != "" do
    Keyword.put(opts, :prompt, prompt)
  end

  defp maybe_put_prompt(opts, _input_mode, _input), do: opts

  defp input_mode(input) when is_binary(input), do: :prompt
  defp input_mode(input) when is_list(input), do: :json_input

  defp options_from_provider_opts(opts) do
    %Options{
      model_payload: Keyword.get(opts, :model_payload),
      mode: Keyword.get(opts, :mode, "smart"),
      dangerously_allow_all: Keyword.get(opts, :dangerously_allow_all, false),
      visibility: Keyword.get(opts, :visibility, "workspace"),
      log_level: Keyword.get(opts, :log_level),
      log_file: Keyword.get(opts, :log_file),
      continue_thread: Keyword.get(opts, :continue_thread),
      mcp_config: Keyword.get(opts, :mcp_config),
      labels: Keyword.get(opts, :labels),
      thinking: Keyword.get(opts, :thinking, false),
      permissions: Keyword.get(opts, :permissions),
      skills: Keyword.get(opts, :skills),
      execution_surface: nil,
      no_ide: Keyword.get(opts, :no_ide, false),
      no_notifications: Keyword.get(opts, :no_notifications, false),
      no_color: Keyword.get(opts, :no_color, false),
      no_jetbrains: Keyword.get(opts, :no_jetbrains, false)
    }
    |> Options.validate!()
  end

  defp maybe_emit_system_message(%CoreEvent{} = event, %ProjectionState{} = state) do
    session_id = session_id(event, state)

    state = %{
      state
      | provider_session_id: choose_session_id(session_id, state.provider_session_id)
    }

    cond do
      state.system_emitted? ->
        {[], state}

      valid_session_id?(session_id) ->
        message =
          system_message!(%{
            "type" => "system",
            "subtype" => "init",
            "session_id" => session_id,
            "cwd" => state.cwd || "",
            "tools" => [],
            "mcp_servers" => []
          })

        {[message], %{state | system_emitted?: true}}

      true ->
        {[], state}
    end
  end

  defp session_id(%CoreEvent{provider_session_id: value}, _state)
       when is_binary(value) and value not in ["", "nil"],
       do: value

  defp session_id(_event, %ProjectionState{provider_session_id: value})
       when is_binary(value) and value not in ["", "nil"],
       do: value

  defp session_id(_event, _state), do: ""

  defp choose_session_id(session_id, current_session_id) do
    if valid_session_id?(session_id), do: session_id, else: current_session_id
  end

  defp normalize_assistant_content(content) when is_list(content) do
    Enum.map(content, fn
      value when is_binary(value) ->
        %{"type" => "text", "text" => value}

      %{"type" => _type} = value ->
        stringify_keys(value)

      %{:type => _type} = value ->
        stringify_keys(value)

      value when is_map(value) ->
        value = stringify_keys(value)

        cond do
          Map.has_key?(value, "text") -> Map.put_new(value, "type", "text")
          Map.has_key?(value, "thinking") -> Map.put_new(value, "type", "thinking")
          true -> value
        end

      value ->
        %{"type" => "text", "text" => to_string(value)}
    end)
  end

  defp normalize_assistant_content(_content), do: []

  defp extract_text_content(content) when is_list(content) do
    content
    |> Enum.flat_map(fn
      %{"type" => "text", "text" => text} when is_binary(text) -> [text]
      _other -> []
    end)
    |> Enum.join()
  end

  defp stringify_content(content) when is_binary(content), do: content
  defp stringify_content(nil), do: ""

  defp stringify_content(content) do
    case Jason.encode(content) do
      {:ok, encoded} -> encoded
      {:error, _reason} -> inspect(content)
    end
  end

  defp usage_from_result(%Payload.Result{output: %{usage: usage}}, _raw) when is_map(usage),
    do: normalize_usage_map(usage)

  defp usage_from_result(_payload, raw) do
    raw
    |> Map.get("usage", Map.get(raw, "token_usage"))
    |> normalize_usage_map()
  end

  defp normalize_usage_map(usage) when is_map(usage) do
    %{
      "input_tokens" => integer_value(usage["input_tokens"] || usage[:input_tokens]),
      "output_tokens" => integer_value(usage["output_tokens"] || usage[:output_tokens]),
      "cache_creation_input_tokens" =>
        integer_value(usage["cache_creation_input_tokens"] || usage[:cache_creation_input_tokens]),
      "cache_read_input_tokens" =>
        integer_value(usage["cache_read_input_tokens"] || usage[:cache_read_input_tokens]),
      "service_tier" => usage["service_tier"] || usage[:service_tier]
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp normalize_usage_map(_usage), do: nil

  defp duration_ms(%Payload.Result{output: %{duration_ms: duration_ms}}, _raw)
       when is_integer(duration_ms),
       do: duration_ms

  defp duration_ms(_payload, raw), do: integer_value(raw["duration_ms"]) || 0

  defp num_turns(raw), do: integer_value(raw["num_turns"]) || 0

  defp truthy?(value) when value in [true, "true", 1, "1", "yes", "on"], do: true
  defp truthy?(_value), do: false

  defp valid_session_id?(value), do: value not in ["", "nil"]

  defp existing_error_kind(code) do
    String.to_existing_atom(code)
  rescue
    ArgumentError ->
      :unknown
  end

  defp integer_value(value) when is_integer(value), do: value

  defp integer_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp integer_value(_value), do: nil

  defp error_message!(
         %Payload.Error{} = payload,
         %{exit: %CoreProcessExit{} = exit},
         session_id,
         _state
       ) do
    kind = normalize_error_kind(payload.code) || :transport_exit

    error_result!(%{
      "type" => "result",
      "subtype" => "error_during_execution",
      "session_id" => session_id,
      "is_error" => true,
      "error" => payload.message || exit_message(exit),
      "kind" => kind,
      "details" =>
        payload.metadata
        |> stringify_keys()
        |> Map.put_new("reason", inspect(exit.reason))
        |> Map.put_new("exit_code", exit.code),
      "exit_code" => exit.code
    })
  end

  defp error_message!(
         %Payload.Error{code: "parse_error", metadata: metadata} = payload,
         _raw,
         session_id,
         _state
       ) do
    error_result!(%{
      "type" => "result",
      "subtype" => "error_during_execution",
      "session_id" => session_id,
      "is_error" => true,
      "error" => "JSON parse error: #{payload.message}",
      "kind" => :parse_error,
      "details" => %{"line" => metadata[:line] || metadata["line"]}
    })
  end

  defp error_message!(
         %Payload.Error{} = payload,
         %CoreTransportError{} = error,
         session_id,
         _state
       ) do
    error_result!(%{
      "type" => "result",
      "subtype" => "error_during_execution",
      "session_id" => session_id,
      "is_error" => true,
      "error" => "Transport error: #{payload.message || error.message}",
      "kind" => :transport_error,
      "details" => stringify_keys(error.context)
    })
  end

  defp error_message!(%Payload.Error{} = payload, raw, session_id, _state) do
    kind = normalize_error_kind(payload.code)

    error_result!(%{
      "type" => "result",
      "subtype" => "error_during_execution",
      "session_id" => session_id,
      "is_error" => true,
      "error" => payload.message,
      "kind" => kind,
      "details" => build_error_details(kind, payload, raw)
    })
  end

  defp build_error_details(:parse_error, %Payload.Error{metadata: metadata}, _raw) do
    %{"line" => metadata[:line] || metadata["line"]}
  end

  defp build_error_details(_kind, %Payload.Error{metadata: metadata}, raw) do
    metadata
    |> stringify_keys()
    |> Map.merge(normalize_raw_map(raw))
  end

  defp normalize_error_kind(nil), do: nil
  defp normalize_error_kind(:unknown), do: nil

  defp normalize_error_kind(code) when is_binary(code) do
    case code do
      "unknown" ->
        nil

      "transport_error" ->
        :transport_error

      "transport_exit" ->
        :transport_exit

      "parse_error" ->
        :parse_error

      "user_cancelled" ->
        :execution_failed

      _other ->
        existing_error_kind(code)
    end
  end

  defp normalize_error_kind(code) when is_atom(code), do: code
  defp normalize_error_kind(_code), do: nil

  defp exit_message(%CoreProcessExit{status: :success, code: code}),
    do: "CLI exited with code #{code || 0}"

  defp exit_message(%CoreProcessExit{status: :exit, code: code}),
    do: "CLI exited with code #{code}"

  defp exit_message(%CoreProcessExit{status: :signal, signal: signal}),
    do: "CLI terminated by signal #{inspect(signal)}"

  defp exit_message(%CoreProcessExit{reason: reason}),
    do: "CLI exited with #{inspect(reason)}"

  defp system_message!(map), do: parse_projected_message!(map)

  defp assistant_message!(session_id, content, model),
    do: parse_projected_message!(assistant_map(session_id, content, model))

  defp user_message!(session_id, content),
    do: parse_projected_message!(user_map(session_id, content))

  defp result_message!(map), do: parse_projected_message!(map)
  defp error_result!(map), do: parse_projected_message!(map)

  defp assistant_map(session_id, content, model) do
    %{
      "type" => "assistant",
      "session_id" => session_id,
      "message" =>
        %{
          "role" => "assistant",
          "model" => model,
          "content" => content
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()
    }
  end

  defp user_map(session_id, content) do
    %{
      "type" => "user",
      "session_id" => session_id,
      "message" => %{"role" => "user", "content" => content}
    }
  end

  defp parse_projected_message!(map) do
    case Types.parse_message_data(map) do
      {:ok, message} -> message
      {:error, reason} -> raise ArgumentError, "invalid projected Amp message: #{inspect(reason)}"
    end
  end

  defp normalize_raw_map(%{} = raw), do: stringify_keys(raw)
  defp normalize_raw_map(_raw), do: %{}

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) ->
        {to_string(key), stringify_keys(value)}

      {key, value} when is_list(value) ->
        {to_string(key), Enum.map(value, &stringify_list_value/1)}

      {key, value} ->
        {to_string(key), value}
    end)
  end

  defp stringify_keys(_value), do: %{}

  defp stringify_list_value(value) when is_map(value), do: stringify_keys(value)
  defp stringify_list_value(value), do: value

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
    |> Util.maybe_append(options.dangerously_allow_all, ["--dangerously-allow-all"])
    |> Util.maybe_append(options.visibility, ["--visibility", options.visibility])
    |> Util.maybe_append(options.log_level, ["--log-level", options.log_level])
    |> Util.maybe_append(options.log_file, ["--log-file", options.log_file])
    |> Util.maybe_append(options.mode, ["--mode", options.mode])
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
    args
    |> Util.maybe_flag(options.no_ide, "--no-ide")
    |> Util.maybe_flag(options.no_notifications, "--no-notifications")
    |> Util.maybe_flag(options.no_color, "--no-color")
    |> Util.maybe_flag(options.no_jetbrains, "--no-jetbrains")
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

  defp encode_permission(%Types.Permission{} = permission) do
    permission
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
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

  defp cleanup_temp_dir(nil), do: :ok
  defp cleanup_temp_dir(dir), do: File.rm_rf(dir)
end
