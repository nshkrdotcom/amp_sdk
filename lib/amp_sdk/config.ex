defmodule AmpSdk.Config do
  @moduledoc false

  @spec normalize_opts(map() | keyword()) :: map()
  def normalize_opts(opts) when is_map(opts), do: opts
  def normalize_opts(opts) when is_list(opts), do: Map.new(opts)

  @spec read_option(map(), atom(), term()) :: term()
  def read_option(opts, key, default \\ nil) when is_map(opts) and is_atom(key) do
    Map.get(opts, key, default)
  end

  @spec fetch_option(map(), atom(), term()) :: {:ok, term()}
  def fetch_option(opts, key, default \\ nil) when is_map(opts) and is_atom(key) do
    {:ok, Map.get(opts, key, default)}
  end

  @spec normalize_string_map(map() | keyword()) :: map()
  def normalize_string_map(entries) when is_map(entries) do
    entries
    |> Map.to_list()
    |> normalize_string_pairs()
  end

  def normalize_string_map(entries) when is_list(entries) do
    normalize_string_pairs(entries)
  end

  defp normalize_string_pairs(entries) do
    Enum.reduce(entries, %{}, fn
      {_key, nil}, acc ->
        acc

      {key, value}, acc ->
        Map.put(acc, to_string(key), to_string(value))
    end)
  end
end
