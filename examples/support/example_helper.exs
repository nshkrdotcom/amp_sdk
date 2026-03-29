defmodule Examples.Support do
  @moduledoc false

  alias AmpSdk.ExamplesSupport

  def init!(argv \\ System.argv()), do: ExamplesSupport.init!(argv)
  def with_execution_surface(options), do: ExamplesSupport.with_execution_surface(options)
  def command_opts(opts \\ []), do: ExamplesSupport.command_opts(opts)
  def invoke(args, opts \\ []), do: ExamplesSupport.invoke(args, opts)
end
