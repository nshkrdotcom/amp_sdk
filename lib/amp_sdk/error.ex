defmodule AmpSdk.Error do
  @moduledoc """
  Unified error envelope for SDK operations.

  All public tuple-based APIs return `{:error, %AmpSdk.Error{}}` for consistent
  pattern matching.
  """

  @enforce_keys [:kind, :message]
  defexception [:kind, :message, :cause, :details, :context, :exit_code]

  @type kind ::
          :cli_not_found
          | :command_failed
          | :command_timeout
          | :command_execution_failed
          | :stream_start_failed
          | :transport_error
          | :parse_error
          | :invalid_message
          | :invalid_configuration
          | :execution_failed
          | :no_result
          | :task_exit
          | :unknown

  @type t :: %__MODULE__{
          kind: kind(),
          message: String.t(),
          cause: term(),
          details: String.t() | nil,
          context: map(),
          exit_code: integer() | nil
        }

  @type normalize_opt ::
          {:kind, kind()}
          | {:message, String.t()}
          | {:cause, term()}
          | {:details, String.t() | nil}
          | {:context, map() | keyword() | nil}
          | {:exit_code, integer() | nil}

  @spec new(kind(), String.t(), [normalize_opt()]) :: t()
  def new(kind, message, opts \\ []) when is_atom(kind) and is_binary(message) do
    %__MODULE__{
      kind: kind,
      message: message,
      cause: Keyword.get(opts, :cause),
      details: Keyword.get(opts, :details),
      context: normalize_context(Keyword.get(opts, :context, %{})),
      exit_code: normalize_exit_code(Keyword.get(opts, :exit_code))
    }
  end

  @spec normalize(term(), [normalize_opt()]) :: t()
  def normalize(reason, opts \\ [])

  def normalize(%__MODULE__{} = error, opts) do
    error
    |> maybe_put(:kind, Keyword.get(opts, :kind))
    |> maybe_put(:message, Keyword.get(opts, :message))
    |> maybe_put(:cause, Keyword.get(opts, :cause))
    |> maybe_put(:details, Keyword.get(opts, :details))
    |> maybe_put(:context, normalize_context(Keyword.get(opts, :context, error.context)))
    |> maybe_put(:exit_code, normalize_exit_code(Keyword.get(opts, :exit_code)))
  end

  def normalize(reason, opts) when is_exception(reason) do
    kind = Keyword.get(opts, :kind, :unknown)
    message = Keyword.get(opts, :message, Exception.message(reason))

    new(kind, message,
      cause: Keyword.get(opts, :cause, reason),
      details: Keyword.get(opts, :details),
      context: Keyword.get(opts, :context),
      exit_code: Keyword.get(opts, :exit_code)
    )
  end

  def normalize(reason, opts) when is_binary(reason) do
    kind = Keyword.get(opts, :kind, :unknown)
    message = Keyword.get(opts, :message, reason)

    new(kind, message,
      cause: Keyword.get(opts, :cause, reason),
      details: Keyword.get(opts, :details),
      context: Keyword.get(opts, :context),
      exit_code: Keyword.get(opts, :exit_code)
    )
  end

  def normalize(reason, opts) when is_atom(reason) do
    kind = Keyword.get(opts, :kind, :unknown)

    new(kind, Keyword.get(opts, :message, Atom.to_string(reason)),
      cause: Keyword.get(opts, :cause, reason),
      details: Keyword.get(opts, :details),
      context: Keyword.get(opts, :context),
      exit_code: Keyword.get(opts, :exit_code)
    )
  end

  def normalize(reason, opts) do
    kind = Keyword.get(opts, :kind, :unknown)

    new(kind, Keyword.get(opts, :message, inspect(reason)),
      cause: Keyword.get(opts, :cause, reason),
      details: Keyword.get(opts, :details),
      context: Keyword.get(opts, :context),
      exit_code: Keyword.get(opts, :exit_code)
    )
  end

  @spec message(term()) :: String.t()
  def message(reason) do
    normalize(reason).message
  end

  defp maybe_put(struct, _field, nil), do: struct
  defp maybe_put(struct, field, value), do: Map.put(struct, field, value)

  defp normalize_context(nil), do: %{}
  defp normalize_context(context) when is_map(context), do: context
  defp normalize_context(context) when is_list(context), do: Map.new(context)
  defp normalize_context(context), do: %{context: context}

  defp normalize_exit_code(code) when is_integer(code), do: code
  defp normalize_exit_code(_), do: nil
end
