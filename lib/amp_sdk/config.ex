defmodule AmpSdk.Config do
  @moduledoc false

  alias AmpSdk.Error

  @spec normalize_opts(map() | keyword()) :: map()
  def normalize_opts(opts) when is_map(opts), do: opts
  def normalize_opts(opts) when is_list(opts), do: Map.new(opts)

  @spec read_option(map(), atom(), term()) :: term()
  def read_option(opts, key, default \\ nil) when is_map(opts) and is_atom(key) do
    case fetch_option(opts, key, default) do
      {:ok, value} ->
        value

      {:error, %Error{} = error} ->
        raise error
    end
  end

  @spec fetch_option(map(), atom(), term()) :: {:ok, term()} | {:error, Error.t()}
  def fetch_option(opts, key, default \\ nil) when is_map(opts) and is_atom(key) do
    string_key = Atom.to_string(key)
    atom_present? = Map.has_key?(opts, key)
    string_present? = Map.has_key?(opts, string_key)
    atom_value = Map.get(opts, key)
    string_value = Map.get(opts, string_key)

    cond do
      atom_present? and string_present? and atom_value != string_value ->
        {:error,
         Error.new(
           :invalid_configuration,
           "Option #{inspect(key)} has conflicting values between atom and string keys",
           context: %{key: key, atom_value: atom_value, string_value: string_value}
         )}

      atom_present? ->
        {:ok, atom_value}

      string_present? ->
        {:ok, string_value}

      true ->
        {:ok, default}
    end
  end

  @spec normalize_string_map(map() | keyword()) :: map()
  def normalize_string_map(entries) when is_map(entries) do
    Map.new(entries, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  def normalize_string_map(entries) when is_list(entries) do
    Map.new(entries, fn {key, value} -> {to_string(key), to_string(value)} end)
  end
end
