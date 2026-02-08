defmodule AmpSdk.Review do
  @moduledoc "Code review via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Defaults, Error, Util}

  @spec run(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def run(opts \\ []) do
    diff = Keyword.get(opts, :diff)
    files = Keyword.get(opts, :files, [])
    instructions = Keyword.get(opts, :instructions)
    check_scope = Keyword.get(opts, :check_scope)
    check_filter = Keyword.get(opts, :check_filter, [])
    summary_only = Keyword.get(opts, :summary_only, false)
    dangerously_allow_all = Keyword.get(opts, :dangerously_allow_all, false)

    args =
      []
      |> Util.maybe_append(dangerously_allow_all, ["--dangerously-allow-all"])
      |> Kernel.++(["review"])
      |> Util.maybe_append(diff, [diff])
      |> Util.maybe_append(files != [], ["--files" | files])
      |> Util.maybe_append(instructions, ["--instructions", instructions])
      |> Util.maybe_append(check_scope, ["--check-scope", check_scope])
      |> Util.maybe_append(check_filter != [], ["--check-filter" | check_filter])
      |> Util.maybe_append(summary_only, ["--summary-only"])

    CLIInvoke.invoke(args, Keyword.put(opts, :default_timeout_ms, Defaults.review_timeout_ms()))
  end
end
