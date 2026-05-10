defmodule AmpSdk.TestSupport do
  @moduledoc false

  def tmp_dir!(prefix \\ "amp_sdk_test") do
    suffix = Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)
    dir = Path.join(System.tmp_dir!(), "#{prefix}_#{suffix}")
    File.mkdir_p!(dir)
    dir
  end

  def write_file!(dir, name, content) do
    path = Path.join(dir, name)
    File.write!(path, content)
    path
  end

  def write_executable!(dir, name, content) do
    path = write_file!(dir, name, content)
    File.chmod!(path, 0o755)
    path
  end

  def with_env(env, fun) when is_function(fun, 0) do
    saved = Enum.map(env, fn {k, _} -> {k, System.get_env(k)} end)
    previous_amp_base_env = Application.fetch_env(:amp_sdk, :base_env)
    previous_provider_env = Application.fetch_env(:cli_subprocess_core, :provider_cli_env)
    previous_live_ssh_env = Application.fetch_env(:cli_subprocess_core, :live_ssh_env)
    materialized_amp_env = materialized_env(previous_amp_base_env, env)
    materialized_provider_env = materialized_env(previous_provider_env, env)
    materialized_live_ssh_env = materialized_env(previous_live_ssh_env, env)

    Enum.each(env, fn
      {k, nil} -> System.delete_env(k)
      {k, v} -> System.put_env(k, v)
    end)

    Application.put_env(:amp_sdk, :base_env, materialized_amp_env)
    Application.put_env(:cli_subprocess_core, :provider_cli_env, materialized_provider_env)
    Application.put_env(:cli_subprocess_core, :live_ssh_env, materialized_live_ssh_env)

    try do
      fun.()
    after
      restore_app_env(:amp_sdk, :base_env, previous_amp_base_env)
      restore_app_env(:provider_cli_env, previous_provider_env)
      restore_app_env(:live_ssh_env, previous_live_ssh_env)

      Enum.each(saved, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end
  end

  defp materialized_env(previous_env, updates) do
    previous_env
    |> previous_materialized_env()
    |> merge_env_updates(updates)
  end

  defp previous_materialized_env({:ok, env}) when is_map(env),
    do: Map.new(env, fn {key, value} -> {to_string(key), to_string(value)} end)

  defp previous_materialized_env(_), do: %{}

  defp merge_env_updates(env, updates) do
    Enum.reduce(updates, env, fn
      {key, nil}, acc -> Map.delete(acc, to_string(key))
      {key, value}, acc -> Map.put(acc, to_string(key), to_string(value))
    end)
  end

  defp restore_app_env(key, {:ok, value}),
    do: Application.put_env(:cli_subprocess_core, key, value)

  defp restore_app_env(key, :error), do: Application.delete_env(:cli_subprocess_core, key)

  defp restore_app_env(app, key, {:ok, value}), do: Application.put_env(app, key, value)
  defp restore_app_env(app, key, :error), do: Application.delete_env(app, key)

  def wait_until(fun, timeout_ms, poll_interval_ms \\ 20)
      when is_function(fun, 0) and is_integer(timeout_ms) and timeout_ms >= 0 and
             is_integer(poll_interval_ms) and poll_interval_ms >= 0 do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_until(fun, deadline, poll_interval_ms)
  end

  defp do_wait_until(fun, deadline, poll_interval_ms) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        :timeout
      else
        receive do
        after
          poll_interval_ms ->
            :ok
        end

        do_wait_until(fun, deadline, poll_interval_ms)
      end
    end
  end
end
