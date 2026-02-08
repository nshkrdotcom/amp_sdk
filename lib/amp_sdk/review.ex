defmodule AmpSdk.Review do
  @moduledoc "Code review via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error}

  @default_timeout_ms 300_000

  @spec run(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def run(opts \\ []) do
    diff = Keyword.get(opts, :diff)
    files = Keyword.get(opts, :files, [])
    instructions = Keyword.get(opts, :instructions)
    check_scope = Keyword.get(opts, :check_scope)
    check_filter = Keyword.get(opts, :check_filter, [])
    summary_only = Keyword.get(opts, :summary_only, false)
    dangerously_allow_all = Keyword.get(opts, :dangerously_allow_all, false)

    args = []
    args = if dangerously_allow_all, do: args ++ ["--dangerously-allow-all"], else: args
    args = args ++ ["review"]
    args = if diff, do: args ++ [diff], else: args
    args = if files != [], do: args ++ ["--files" | files], else: args
    args = if instructions, do: args ++ ["--instructions", instructions], else: args
    args = if check_scope, do: args ++ ["--check-scope", check_scope], else: args
    args = if check_filter != [], do: args ++ ["--check-filter" | check_filter], else: args
    args = if summary_only, do: args ++ ["--summary-only"], else: args

    CLIInvoke.invoke(args, Keyword.put(opts, :default_timeout_ms, @default_timeout_ms))
  end
end
