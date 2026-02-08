defmodule AmpSdk.Usage do
  @moduledoc "Usage and credit balance via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error}

  @spec info() :: {:ok, String.t()} | {:error, Error.t()}
  def info do
    CLIInvoke.invoke(["usage"])
  end
end
