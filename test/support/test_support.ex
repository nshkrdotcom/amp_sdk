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

    Enum.each(env, fn
      {k, nil} -> System.delete_env(k)
      {k, v} -> System.put_env(k, v)
    end)

    try do
      fun.()
    after
      Enum.each(saved, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end
  end

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
