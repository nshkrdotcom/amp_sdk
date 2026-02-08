defmodule AmpSdk.CLIInvoke do
  @moduledoc false

  alias AmpSdk.{CommandRunner, Error, Util}

  @type invoke_opt ::
          {:timeout, non_neg_integer() | :infinity}
          | {:stdin, iodata()}
          | {:default_timeout_ms, pos_integer()}

  @type invoke_result :: {:ok, String.t()} | {:error, Error.t()}

  @spec invoke([String.t()], [invoke_opt() | {atom(), term()}]) :: invoke_result()
  def invoke(args, opts \\ []) when is_list(args) and is_list(opts) do
    run_opts =
      opts
      |> Keyword.take([:timeout])
      |> Util.maybe_put_kw(:stdin, Keyword.get(opts, :stdin))

    case Keyword.get(opts, :default_timeout_ms) do
      timeout when is_integer(timeout) and timeout > 0 ->
        CommandRunner.run(args, run_opts, timeout)

      _ ->
        CommandRunner.run(args, run_opts)
    end
  end
end
