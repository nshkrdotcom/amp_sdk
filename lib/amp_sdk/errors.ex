defmodule AmpSdk.Errors do
  @moduledoc """
  Legacy error types for backward compatibility.

  New code should use `AmpSdk.Error`.
  """

  defmodule AmpError do
    defexception [:message, :exit_code, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            exit_code: integer(),
            details: String.t()
          }

    @impl true
    def exception(opts) when is_list(opts) do
      %__MODULE__{
        message: Keyword.fetch!(opts, :message),
        exit_code: Keyword.get(opts, :exit_code, 1),
        details: Keyword.get(opts, :details, "")
      }
    end

    def exception(message) when is_binary(message) do
      %__MODULE__{message: message, exit_code: 1, details: ""}
    end
  end

  defmodule CLINotFoundError do
    defexception [:message, :exit_code, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            exit_code: integer(),
            details: String.t()
          }

    @impl true
    def exception(opts) when is_list(opts) do
      %__MODULE__{
        message: Keyword.get(opts, :message, "Amp CLI not found"),
        exit_code: 127,
        details:
          Keyword.get(
            opts,
            :details,
            "Please install the Amp CLI: curl -fsSL https://ampcode.com/install.sh | bash"
          )
      }
    end

    def exception(message) when is_binary(message) do
      %__MODULE__{
        message: message,
        exit_code: 127,
        details: "Please install the Amp CLI: curl -fsSL https://ampcode.com/install.sh | bash"
      }
    end
  end

  defmodule ProcessError do
    defexception [:message, :exit_code, :stderr, :signal]

    @type t :: %__MODULE__{
            message: String.t(),
            exit_code: integer(),
            stderr: String.t(),
            signal: String.t()
          }

    @impl true
    def exception(opts) when is_list(opts) do
      %__MODULE__{
        message: Keyword.fetch!(opts, :message),
        exit_code: Keyword.get(opts, :exit_code, 1),
        stderr: Keyword.get(opts, :stderr, ""),
        signal: Keyword.get(opts, :signal, "")
      }
    end
  end

  defmodule JSONParseError do
    defexception [:message, :raw_line]

    @type t :: %__MODULE__{
            message: String.t(),
            raw_line: String.t()
          }

    @impl true
    def exception(opts) when is_list(opts) do
      %__MODULE__{
        message: Keyword.fetch!(opts, :message),
        raw_line: Keyword.get(opts, :raw_line, "")
      }
    end
  end
end
