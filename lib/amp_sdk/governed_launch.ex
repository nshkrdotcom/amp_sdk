defmodule AmpSdk.GovernedLaunch do
  @moduledoc false

  alias AmpSdk.{Error, Types}
  alias CliSubprocessCore.{Command, ExecutionSurface, GovernedAuthority}

  @option_smuggling_fields [
    :cwd,
    :settings_file,
    :log_level,
    :log_file,
    :env,
    :mcp_config,
    :toolbox,
    :skills,
    :permissions,
    :execution_surface,
    :dangerously_allow_all
  ]

  @command_smuggling_fields [
    :cli_command,
    :command,
    :command_spec,
    :cli_path,
    :executable,
    :cd,
    :cwd,
    :env,
    :settings_file,
    :settings_path,
    :log_level,
    :log_file,
    :mcp_config,
    :toolbox,
    :skills,
    :permissions,
    :execution_surface,
    :clear_env?,
    :clear_env
  ]

  @native_state_fields [
    :env,
    :header,
    :headers,
    :server_url,
    :client_id,
    :client_secret,
    :scopes,
    :auth_url,
    :token_url,
    :workspace,
    :settings_file,
    :permissions,
    :skills,
    :mcp_config
  ]

  @spec authority(Types.Options.t() | keyword() | map() | nil) ::
          {:ok, GovernedAuthority.t() | nil} | {:error, term()}
  def authority(%Types.Options{governed_authority: authority}),
    do: GovernedAuthority.new(authority)

  def authority(opts) when is_list(opts),
    do: GovernedAuthority.new(Keyword.get(opts, :governed_authority))

  def authority(%{} = opts), do: GovernedAuthority.new(Map.get(opts, :governed_authority))
  def authority(nil), do: {:ok, nil}

  @spec governed?(Types.Options.t() | keyword() | map() | nil) :: boolean()
  def governed?(input) do
    case authority(input) do
      {:ok, %GovernedAuthority{}} -> true
      _ -> false
    end
  end

  @spec validate_options(Types.Options.t()) :: :ok | {:error, term()}
  def validate_options(%Types.Options{} = options) do
    with {:ok, authority} <- authority(options) do
      validate_options(options, authority)
    end
  end

  @spec validate_options!(Types.Options.t()) :: Types.Options.t()
  def validate_options!(%Types.Options{} = options) do
    case validate_options(options) do
      :ok ->
        options

      {:error, reason} ->
        raise ArgumentError, "governed Amp launch rejected: #{inspect(reason)}"
    end
  end

  @spec validate_command_options(keyword()) :: :ok | {:error, term()}
  def validate_command_options(opts) when is_list(opts) do
    with {:ok, authority} <- authority(opts) do
      validate_command_options(opts, authority)
    end
  end

  @spec validate_native_state(keyword(), atom()) :: :ok | {:error, Error.t()}
  def validate_native_state(opts, scope) when is_list(opts) and is_atom(scope) do
    with {:ok, authority} <- authority(opts) do
      validate_native_state(opts, authority, scope)
    end
  end

  @spec invocation([String.t()], Types.Options.t() | keyword()) ::
          {:ok, Command.t()} | {:error, term()}
  def invocation(args, input) when is_list(args) do
    with {:ok, %GovernedAuthority{} = authority} <- authority(input),
         :ok <- validate_invocation_input(input) do
      {:ok,
       Command.new(
         GovernedAuthority.command_spec(authority),
         args,
         GovernedAuthority.launch_options(authority)
       )}
    end
  end

  @spec run_options(keyword(), Types.Options.t() | keyword()) :: keyword()
  def run_options(opts, input) when is_list(opts) do
    case authority(input) do
      {:ok, %GovernedAuthority{} = authority} -> Keyword.put(opts, :governed_authority, authority)
      _ -> opts
    end
  end

  @spec error(term()) :: Error.t()
  def error(reason) do
    Error.new(
      :invalid_configuration,
      "governed Amp launch rejected: #{inspect(reason)}",
      cause: reason
    )
  end

  defp validate_options(_options, nil), do: :ok

  defp validate_options(%Types.Options{} = options, %GovernedAuthority{}) do
    cond do
      field = first_present_option_field(options, @option_smuggling_fields) ->
        {:error, {:governed_launch_smuggling, field}}

      model_payload_env_overrides?(options.model_payload) ->
        {:error, {:governed_launch_smuggling, :model_payload, :env_overrides}}

      true ->
        :ok
    end
  end

  defp validate_command_options(_opts, nil), do: :ok

  defp validate_command_options(opts, %GovernedAuthority{}) do
    cond do
      key = first_present_keyword(opts, @command_smuggling_fields) ->
        {:error, {:governed_launch_smuggling, key}}

      model_payload_env_overrides?(Keyword.get(opts, :model_payload)) ->
        {:error, {:governed_launch_smuggling, :model_payload, :env_overrides}}

      true ->
        :ok
    end
  end

  defp validate_native_state(_opts, nil, _scope), do: :ok

  defp validate_native_state(opts, %GovernedAuthority{}, scope) do
    case first_present_keyword(opts, @native_state_fields) do
      nil -> {:error, error({:governed_native_state_unsupported, scope})}
      key -> {:error, error({:governed_native_state_smuggling, scope, key})}
    end
  end

  defp validate_invocation_input(%Types.Options{} = options), do: validate_options(options)
  defp validate_invocation_input(opts) when is_list(opts), do: validate_command_options(opts)

  defp first_present_option_field(options, fields) do
    Enum.find(fields, fn field -> present_option_value?(field, Map.get(options, field)) end)
  end

  defp present_option_value?(:execution_surface, %ExecutionSurface{} = surface),
    do: surface != %ExecutionSurface{}

  defp present_option_value?(_field, value), do: present?(value)

  defp first_present_keyword(opts, fields) do
    Enum.find(fields, fn field ->
      Keyword.has_key?(opts, field) and present_keyword_value?(field, Keyword.get(opts, field))
    end)
  end

  defp present_keyword_value?(:execution_surface, %ExecutionSurface{} = surface),
    do: surface != %ExecutionSurface{}

  defp present_keyword_value?(_field, value), do: present?(value)

  defp present?(nil), do: false
  defp present?(false), do: false
  defp present?(""), do: false
  defp present?([]), do: false
  defp present?(%{} = value), do: map_size(value) > 0
  defp present?(_value), do: true

  defp model_payload_env_overrides?(payload) when is_map(payload) do
    case payload_value(payload, :env_overrides) do
      %{} = env -> map_size(env) > 0
      _ -> false
    end
  end

  defp model_payload_env_overrides?(_payload), do: false

  defp payload_value(payload, key) when is_map(payload) do
    Map.get(payload, key, Map.get(payload, Atom.to_string(key)))
  end
end
