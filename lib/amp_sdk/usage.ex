defmodule AmpSdk.Usage do
  @moduledoc "Usage and credit balance via the Amp CLI."

  alias AmpSdk.{CommandRunner, Error}

  @spec info() :: {:ok, String.t()} | {:error, Error.t()}
  def info do
    CommandRunner.run(["usage"])
  end
end
