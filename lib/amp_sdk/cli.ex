defmodule AmpSdk.CLI do
  @moduledoc "Discovers and resolves the Amp CLI executable."

  import Bitwise

  alias AmpSdk.{Defaults, Error, TaskSupport}

  defmodule CommandSpec do
    @moduledoc "Executable command configuration for invoking the Amp CLI."

    @enforce_keys [:program]
    defstruct program: "", argv_prefix: []

    @type t :: %__MODULE__{
            program: String.t(),
            argv_prefix: [String.t()]
          }
  end

  @type resolution_result :: {:ok, CommandSpec.t()} | {:error, Error.t()}

  @spec resolve() :: resolution_result()
  def resolve do
    with :error <- check_env_var(),
         :error <- check_binary_paths(),
         :error <- check_path(),
         :error <- check_node_resolve() do
      {:error,
       Error.new(
         :cli_not_found,
         Defaults.cli_not_found_message(),
         exit_code: 127
       )}
    end
  end

  @spec resolve!() :: CommandSpec.t()
  def resolve!() do
    case resolve() do
      {:ok, spec} -> spec
      {:error, error} -> raise error
    end
  end

  @spec command_args(CommandSpec.t(), [String.t()]) :: [String.t()]
  def command_args(%CommandSpec{argv_prefix: prefix}, args) when is_list(args) do
    prefix ++ args
  end

  defp check_env_var do
    with path when is_binary(path) <- System.get_env("AMP_CLI_PATH") do
      resolve_cli_path(path, System.find_executable("node"))
    else
      _ -> :error
    end
  end

  defp resolve_cli_path(path, node_path) do
    cond do
      not File.regular?(path) ->
        :error

      String.ends_with?(path, ".js") and is_binary(node_path) ->
        {:ok, %CommandSpec{program: node_path, argv_prefix: [path]}}

      String.ends_with?(path, ".js") ->
        :error

      executable?(path) ->
        {:ok, %CommandSpec{program: path, argv_prefix: []}}

      true ->
        :error
    end
  end

  defp check_binary_paths do
    home = System.get_env("HOME") || System.user_home!()

    [
      Path.join([home, ".amp", "bin", "amp"]),
      Path.join([home, ".local", "bin", "amp"])
    ]
    |> Enum.find_value(:error, fn path ->
      resolve_cli_path(path, System.find_executable("node"))
    end)
  end

  defp check_path do
    case System.find_executable("amp") do
      nil -> :error
      path -> {:ok, %CommandSpec{program: path, argv_prefix: []}}
    end
  end

  defp check_node_resolve do
    with node when is_binary(node) <- System.find_executable("node"),
         {output, 0} <- run_node_probe(node),
         result <- resolve_node_package(String.trim(output), node),
         {:ok, _spec} <- result do
      result
    else
      _ -> :error
    end
  rescue
    _error in [File.Error, Jason.DecodeError, ErlangError] -> :error
  end

  defp run_node_probe(node) do
    case TaskSupport.async_nolink(fn ->
           System.cmd(node, ["-p", "require.resolve('@sourcegraph/amp/package.json')"],
             stderr_to_stdout: true
           )
         end) do
      {:ok, task} ->
        case Task.yield(task, Defaults.cli_node_probe_timeout_ms()) ||
               Task.shutdown(task, :brutal_kill) do
          {:ok, {output, status}} when is_binary(output) and is_integer(status) ->
            {output, status}

          _ ->
            :error
        end

      {:error, _reason} ->
        :error
    end
  end

  defp resolve_node_package(package_json_path, node_path) do
    package_dir = Path.dirname(package_json_path)

    with {:ok, content} <- File.read(package_json_path),
         {:ok, data} <- Jason.decode(content),
         %{"bin" => %{"amp" => bin_path}} <- data,
         full_bin = Path.join(package_dir, bin_path),
         true <- File.regular?(full_bin) do
      resolve_cli_path(full_bin, node_path)
    else
      _ -> :error
    end
  end

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular, mode: mode}} ->
        (mode &&& 0o111) != 0

      _ ->
        false
    end
  end
end
