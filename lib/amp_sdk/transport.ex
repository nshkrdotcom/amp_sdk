defmodule AmpSdk.Transport do
  @moduledoc "Behaviour for CLI transport implementations."

  @type t :: pid()
  @type message :: binary()
  @type opts :: keyword()
  @type subscription_tag :: :legacy | reference()

  @callback start(opts()) :: {:ok, t()} | {:error, term()}
  @callback start_link(opts()) :: {:ok, t()} | {:error, term()}
  @callback send(t(), message()) :: :ok | {:error, term()}
  @callback subscribe(t(), pid()) :: :ok | {:error, term()}
  @callback subscribe(t(), pid(), subscription_tag()) :: :ok | {:error, term()}
  @callback close(t()) :: :ok
  @callback force_close(t()) :: :ok
  @callback status(t()) :: :connected | :disconnected | :error
  @callback end_input(t()) :: :ok | {:error, term()}
end
