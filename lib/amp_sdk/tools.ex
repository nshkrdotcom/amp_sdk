defmodule AmpSdk.Tools do
  @moduledoc "Tool management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error, Util}

  @spec list() :: {:ok, String.t()} | {:error, Error.t()}
  def list do
    CLIInvoke.invoke(["tools", "list"])
  end

  @spec show(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def show(tool_name) when is_binary(tool_name) do
    CLIInvoke.invoke(["tools", "show", tool_name])
  end

  @spec use(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def use(tool_name, opts \\ []) when is_binary(tool_name) do
    args = ["tools", "use", tool_name]
    args = if opts[:only], do: args ++ ["--only", opts[:only]], else: args
    args = if opts[:stream], do: args ++ ["--stream"], else: args

    tool_args = Keyword.get(opts, :args, [])

    args =
      Enum.reduce(tool_args, args, &append_tool_arg/2)

    run_opts =
      opts
      |> Keyword.take([:timeout])
      |> Util.maybe_put_kw(:stdin, Keyword.get(opts, :input))

    CLIInvoke.invoke(args, run_opts)
  end

  @spec make(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def make(tool_name, opts \\ []) when is_binary(tool_name) and is_list(opts) do
    CLIInvoke.invoke(["tools", "make", tool_name], opts)
  end

  defp append_tool_arg({_key, nil}, acc), do: acc

  defp append_tool_arg({key, values}, acc) when is_list(values) do
    flag = "--#{key}"

    Enum.reduce(values, acc, fn value, inner ->
      inner ++ [flag, encode_tool_value(value)]
    end)
  end

  defp append_tool_arg({key, value}, acc) do
    acc ++ ["--#{key}", encode_tool_value(value)]
  end

  defp append_tool_arg(arg, acc) when is_binary(arg), do: acc ++ [arg]

  defp encode_tool_value(value) when is_map(value), do: Jason.encode!(value)
  defp encode_tool_value(value), do: to_string(value)
end
