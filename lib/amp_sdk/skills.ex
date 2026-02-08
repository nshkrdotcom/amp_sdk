defmodule AmpSdk.Skills do
  @moduledoc "Skill management via the Amp CLI."

  alias AmpSdk.{CLIInvoke, Error}

  @spec add(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def add(source) when is_binary(source) do
    CLIInvoke.invoke(["skill", "add", source])
  end

  @spec list() :: {:ok, String.t()} | {:error, Error.t()}
  def list do
    CLIInvoke.invoke(["skill", "list"])
  end

  @spec remove(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def remove(skill_name) when is_binary(skill_name) do
    CLIInvoke.invoke(["skill", "remove", skill_name])
  end

  @spec info(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def info(skill_name) when is_binary(skill_name) do
    CLIInvoke.invoke(["skill", "info", skill_name])
  end
end
