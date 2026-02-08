defmodule AmpSdk.Util do
  @moduledoc false

  @spec maybe_put_kw(keyword(), atom(), term()) :: keyword()
  def maybe_put_kw(opts, _key, nil), do: opts
  def maybe_put_kw(opts, key, value), do: Keyword.put(opts, key, value)

  @spec maybe_append(list(), term(), list()) :: list()
  def maybe_append(items, nil, _extra), do: items
  def maybe_append(items, false, _extra), do: items
  def maybe_append(items, _truthy, extra), do: items ++ extra

  @spec maybe_flag([String.t()], boolean() | nil, String.t()) :: [String.t()]
  def maybe_flag(args, true, flag), do: args ++ [flag]
  def maybe_flag(args, _value, _flag), do: args
end
