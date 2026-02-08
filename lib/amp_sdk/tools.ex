defmodule AmpSdk.Tools do
  @moduledoc "Tool management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error}

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
      Enum.reduce(tool_args, args, fn
        {key, value}, acc -> acc ++ ["--#{key}", to_string(value)]
        arg, acc when is_binary(arg) -> acc ++ [arg]
      end)

    run_opts =
      opts
      |> Keyword.take([:timeout])
      |> maybe_put_stdin(Keyword.get(opts, :input))

    CLIInvoke.invoke(args, run_opts)
  end

  @spec make(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def make(tool_name) when is_binary(tool_name) do
    CLIInvoke.invoke(["tools", "make", tool_name])
  end

  defp maybe_put_stdin(run_opts, nil), do: run_opts
  defp maybe_put_stdin(run_opts, input), do: Keyword.put(run_opts, :stdin, input)
end
