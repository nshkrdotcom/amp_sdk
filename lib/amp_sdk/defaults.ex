defmodule AmpSdk.Defaults do
  @moduledoc false

  @command_timeout_ms 60_000
  @review_timeout_ms 300_000
  @stream_timeout_ms 300_000
  @stream_max_stderr_buffer_bytes 262_144
  @transport_call_timeout_ms 5_000
  @transport_force_close_timeout_ms 500
  @transport_headless_timeout_ms 5_000
  @cli_install_command "curl -fsSL https://ampcode.com/install.sh | bash"
  @cli_not_found_message "Amp CLI not found. Install it with: #{@cli_install_command}"

  @spec command_timeout_ms() :: pos_integer()
  def command_timeout_ms, do: @command_timeout_ms

  @spec review_timeout_ms() :: pos_integer()
  def review_timeout_ms, do: @review_timeout_ms

  @spec stream_timeout_ms() :: pos_integer()
  def stream_timeout_ms, do: @stream_timeout_ms

  @spec stream_max_stderr_buffer_bytes() :: pos_integer()
  def stream_max_stderr_buffer_bytes, do: @stream_max_stderr_buffer_bytes

  @spec transport_call_timeout_ms() :: pos_integer()
  def transport_call_timeout_ms, do: @transport_call_timeout_ms

  @spec transport_force_close_timeout_ms() :: pos_integer()
  def transport_force_close_timeout_ms, do: @transport_force_close_timeout_ms

  @spec transport_headless_timeout_ms() :: pos_integer()
  def transport_headless_timeout_ms, do: @transport_headless_timeout_ms

  @spec cli_install_command() :: String.t()
  def cli_install_command, do: @cli_install_command

  @spec cli_not_found_message() :: String.t()
  def cli_not_found_message, do: @cli_not_found_message
end
