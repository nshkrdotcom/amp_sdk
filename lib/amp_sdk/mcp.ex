defmodule AmpSdk.MCP do
  @moduledoc "MCP server management via the Amp CLI."

  alias AmpSdk.{CommandRunner, Error}

  @spec add(String.t(), String.t() | [String.t()], keyword()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def add(name, command_or_url, opts \\ [])

  def add(name, url, opts) when is_binary(name) and is_binary(url) do
    timeout_opts = Keyword.take(opts, [:timeout])
    CommandRunner.run(["mcp", "add", name, url], timeout_opts)
  end

  def add(name, [command | args], opts) when is_binary(name) do
    base = ["mcp", "add", name]

    base =
      if opts[:env] do
        Enum.reduce(opts[:env], base, fn {key, value}, acc ->
          acc ++ ["--env", "#{key}=#{value}"]
        end)
      else
        base
      end

    timeout_opts = Keyword.take(opts, [:timeout])
    CommandRunner.run(base ++ ["--", command | args], timeout_opts)
  end

  @spec list() :: {:ok, String.t()} | {:error, Error.t()}
  def list do
    CommandRunner.run(["mcp", "list"])
  end

  @spec remove(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def remove(name) when is_binary(name) do
    CommandRunner.run(["mcp", "remove", name])
  end

  @spec doctor() :: {:ok, String.t()} | {:error, Error.t()}
  def doctor do
    CommandRunner.run(["mcp", "doctor"])
  end

  @spec approve(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def approve(name) when is_binary(name) do
    CommandRunner.run(["mcp", "approve", name])
  end

  @spec oauth_login(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def oauth_login(server_name, opts \\ []) when is_binary(server_name) do
    args = ["mcp", "oauth", "login", server_name]
    args = if opts[:client_id], do: args ++ ["--client-id", opts[:client_id]], else: args

    args =
      if opts[:client_secret], do: args ++ ["--client-secret", opts[:client_secret]], else: args

    CommandRunner.run(args, Keyword.take(opts, [:timeout]))
  end

  @spec oauth_logout(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def oauth_logout(server_name) when is_binary(server_name) do
    CommandRunner.run(["mcp", "oauth", "logout", server_name])
  end

  @spec oauth_status(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def oauth_status(server_name) when is_binary(server_name) do
    CommandRunner.run(["mcp", "oauth", "status", server_name])
  end
end
