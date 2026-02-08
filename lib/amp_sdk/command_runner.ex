defmodule AmpSdk.CommandRunner do
  @moduledoc false

  alias AmpSdk.{Command, Defaults, Error}

  @type run_result :: {:ok, String.t()} | {:error, Error.t()}

  @spec run([String.t()], keyword()) :: run_result()
  def run(args, opts \\ [])
      when is_list(args) and is_list(opts) do
    run(args, opts, Defaults.command_timeout_ms())
  end

  @spec run([String.t()], keyword(), non_neg_integer()) :: run_result()
  def run(args, opts, default_timeout_ms)
      when is_list(args) and is_list(opts) and is_integer(default_timeout_ms) and
             default_timeout_ms > 0 do
    timeout = Keyword.get(opts, :timeout, default_timeout_ms)
    Command.run(args, Keyword.put(opts, :timeout, timeout))
  end

  @spec default_timeout_ms() :: pos_integer()
  def default_timeout_ms, do: Defaults.command_timeout_ms()
end
