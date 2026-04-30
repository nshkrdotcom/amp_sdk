#!/usr/bin/env elixir

# SDK-direct Amp promotion-path verifier.
#
# Usage:
#   mix run examples/promotion_path/sdk_direct_amp.exs -- \
#     --prompt "Reply with exactly: amp sdk direct ok"
#
# Optional:
#   --cwd /path/to/workdir

defmodule AmpPromotionPath.Direct do
  @moduledoc false

  alias AmpSdk.Types.Options

  @switches [
    cwd: :string,
    prompt: :string
  ]

  def main(argv) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @switches)
    reject_invalid!(invalid)

    prompt = Keyword.get(opts, :prompt) || Enum.join(args, " ")
    prompt = if String.trim(prompt) == "", do: "Reply with exactly: amp sdk direct ok", else: prompt

    options =
      %Options{
        cwd: Keyword.get(opts, :cwd),
        mode: "smart",
        permissions: [
          AmpSdk.create_permission("Bash", "reject"),
          AmpSdk.create_permission("edit_file", "reject"),
          AmpSdk.create_permission("create_file", "reject")
        ],
        no_ide: true,
        no_notifications: true,
        execution_surface: [
          surface_kind: :local_subprocess,
          observability: %{suite: :promotion_path, lane: :sdk_direct, provider: :amp}
        ]
      }

    case AmpSdk.run(prompt, options) do
      {:ok, response} ->
        IO.puts(response)

      {:error, error} ->
        IO.puts(:stderr, "Amp SDK-direct example failed: #{Exception.message(error)}")
        System.halt(1)
    end
  end

  defp reject_invalid!([]), do: :ok

  defp reject_invalid!(invalid) do
    raise ArgumentError, "invalid options: #{inspect(invalid)}"
  end
end

AmpPromotionPath.Direct.main(System.argv())

