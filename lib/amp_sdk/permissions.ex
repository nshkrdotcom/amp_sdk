defmodule AmpSdk.Permissions do
  @moduledoc "Permission management via the Amp CLI."

  alias AmpSdk.{CommandRunner, Error}

  @spec list() :: {:ok, String.t()} | {:error, Error.t()}
  def list do
    CommandRunner.run(["permissions", "list"])
  end

  @spec test(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def test(tool_name, opts \\ []) when is_binary(tool_name) do
    args = ["permissions", "test", tool_name]

    tool_args = Keyword.get(opts, :args, [])

    args =
      Enum.reduce(tool_args, args, fn
        {key, value}, acc -> acc ++ ["--#{key}", to_string(value)]
      end)

    CommandRunner.run(args, Keyword.take(opts, [:timeout]))
  end

  @spec add(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def add(tool, action, opts \\ []) when is_binary(tool) and is_binary(action) do
    args = ["permissions", "add", action, tool]
    args = if opts[:context], do: args ++ ["--context", to_string(opts[:context])], else: args
    args = if opts[:to], do: args ++ ["--to", to_string(opts[:to])], else: args
    args = if opts[:workspace], do: args ++ ["--workspace"], else: args

    CommandRunner.run(args, Keyword.take(opts, [:timeout]))
  end
end
