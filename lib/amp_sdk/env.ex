defmodule AmpSdk.Env do
  @moduledoc false

  @base_env_keys ~w(PATH HOME USER LOGNAME SHELL TERM TMPDIR TEMP TMP)

  @spec filtered_system_env() :: map()
  def filtered_system_env do
    System.get_env()
    |> Enum.filter(fn {key, value} ->
      allowed_system_key?(key) and valid_env_key?(key) and is_binary(value)
    end)
    |> Map.new()
  end

  @spec normalize_overrides(map() | keyword() | nil) :: map()
  def normalize_overrides(nil), do: %{}

  def normalize_overrides(overrides) when is_map(overrides) do
    normalize_pairs(Map.to_list(overrides))
  end

  def normalize_overrides(overrides) when is_list(overrides) do
    normalize_pairs(overrides)
  end

  @spec merge_overrides(map() | keyword() | nil) :: map()
  def merge_overrides(overrides) do
    Map.merge(filtered_system_env(), normalize_overrides(overrides))
  end

  @spec sdk_version() :: String.t()
  def sdk_version do
    case Application.spec(:amp_sdk, :vsn) do
      nil -> "unknown"
      vsn when is_list(vsn) -> List.to_string(vsn)
      vsn -> to_string(vsn)
    end
  end

  @spec sdk_version_tag() :: String.t()
  def sdk_version_tag do
    "elixir-" <> sdk_version()
  end

  @spec valid_env_key?(String.t()) :: boolean()
  def valid_env_key?(key) when is_binary(key) do
    String.match?(key, ~r/^[A-Za-z_][A-Za-z0-9_]*$/)
  end

  def valid_env_key?(_), do: false

  defp normalize_pairs(pairs) do
    Enum.reduce(pairs, %{}, fn
      {key, value}, acc ->
        normalized_key = to_string(key)

        if valid_env_key?(normalized_key) do
          Map.put(acc, normalized_key, to_string(value))
        else
          acc
        end

      _, acc ->
        acc
    end)
  end

  defp allowed_system_key?(key) do
    key in @base_env_keys or String.starts_with?(key, "AMP_")
  end
end
