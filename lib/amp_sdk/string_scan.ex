defmodule AmpSdk.StringScan do
  @moduledoc false

  @spec contains_any_ci?(String.t(), [String.t()]) :: boolean()
  def contains_any_ci?(value, needles) when is_binary(value) and is_list(needles) do
    value = String.downcase(value)

    Enum.any?(needles, fn needle ->
      String.contains?(value, String.downcase(needle))
    end)
  end

  def contains_any_ci?(_value, _needles), do: false

  @spec ascii_env_key?(term()) :: boolean()
  def ascii_env_key?(<<first, rest::binary>>)
      when first == ?_ or (first >= ?A and first <= ?Z) or (first >= ?a and first <= ?z) do
    ascii_env_key_rest?(rest)
  end

  def ascii_env_key?(_key), do: false

  @spec ascii_alphanumeric_or_dash?(term()) :: boolean()
  def ascii_alphanumeric_or_dash?(value) when is_binary(value) and value != "" do
    value
    |> :binary.bin_to_list()
    |> Enum.all?(fn byte -> ascii_alphanumeric?(byte) or byte == ?- end)
  end

  def ascii_alphanumeric_or_dash?(_value), do: false

  @spec split_on_repeated_spaces(String.t()) :: [String.t()]
  def split_on_repeated_spaces(value) when is_binary(value) do
    value
    |> do_split_on_repeated_spaces([], [])
    |> Enum.reject(&(&1 == ""))
  end

  @spec non_alphanumeric_separator?(String.t()) :: boolean()
  def non_alphanumeric_separator?(value) when is_binary(value) do
    bytes =
      value
      |> String.trim()
      |> :binary.bin_to_list()
      |> Enum.reject(&(&1 == ?\s))

    bytes != [] and Enum.all?(bytes, &(not ascii_alphanumeric?(&1)))
  end

  def non_alphanumeric_separator?(_value), do: false

  defp do_split_on_repeated_spaces(<<"  ", rest::binary>>, current, acc) do
    rest
    |> trim_leading_spaces()
    |> do_split_on_repeated_spaces([], [current_to_column(current) | acc])
  end

  defp do_split_on_repeated_spaces(<<char::utf8, rest::binary>>, current, acc) do
    do_split_on_repeated_spaces(rest, [current, <<char::utf8>>], acc)
  end

  defp do_split_on_repeated_spaces(<<>>, current, acc) do
    [current_to_column(current) | acc]
    |> Enum.reverse()
  end

  defp current_to_column(current) do
    current
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp trim_leading_spaces(<<" ", rest::binary>>), do: trim_leading_spaces(rest)
  defp trim_leading_spaces(rest), do: rest

  defp ascii_env_key_rest?(<<char, rest::binary>>)
       when char == ?_ or (char >= ?A and char <= ?Z) or (char >= ?a and char <= ?z) or
              (char >= ?0 and char <= ?9) do
    ascii_env_key_rest?(rest)
  end

  defp ascii_env_key_rest?(<<>>), do: true
  defp ascii_env_key_rest?(_rest), do: false

  defp ascii_alphanumeric?(char), do: ascii_letter?(char) or ascii_digit?(char)

  defp ascii_letter?(char), do: (char >= ?A and char <= ?Z) or (char >= ?a and char <= ?z)
  defp ascii_digit?(char), do: char >= ?0 and char <= ?9
end
