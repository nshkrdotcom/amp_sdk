defmodule AmpSdk.Config do
  @moduledoc false

  @spec normalize_opts(map() | keyword()) :: map()
  def normalize_opts(opts) when is_map(opts), do: opts
  def normalize_opts(opts) when is_list(opts), do: Map.new(opts)

  @spec read_option(map(), atom(), term()) :: term()
  def read_option(opts, key, default \\ nil) when is_map(opts) and is_atom(key) do
    Map.get(opts, key, Map.get(opts, Atom.to_string(key), default))
  end

  @spec normalize_string_map(map() | keyword()) :: map()
  def normalize_string_map(entries) when is_map(entries) do
    Map.new(entries, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  def normalize_string_map(entries) when is_list(entries) do
    Map.new(entries, fn {key, value} -> {to_string(key), to_string(value)} end)
  end
end
