defmodule AmpSdk.EnvTest do
  use ExUnit.Case, async: true

  alias AmpSdk.TestSupport
  alias AmpSdk.Types.Options

  test "build_env uses application version for AMP_SDK_VERSION" do
    env = AmpSdk.Stream.build_env(%Options{})

    assert env["AMP_SDK_VERSION"] == "elixir-" <> to_string(Application.spec(:amp_sdk, :vsn))
  end

  test "Command and Stream share the same baseline env filtering" do
    TestSupport.with_env(
      %{
        "AMP_VALID_ALPHA" => "one",
        "AMP.INVALID.KEY" => "two",
        "NOT_AMP_KEY" => "three"
      },
      fn ->
        stream_env = AmpSdk.Stream.build_env(%Options{})

        assert stream_env["AMP_VALID_ALPHA"] == "one"
        refute Map.has_key?(stream_env, "AMP.INVALID.KEY")
        refute Map.has_key?(stream_env, "NOT_AMP_KEY")

        # Command path should use the same filter logic and preserve valid AMP_* overrides.
        dir = TestSupport.tmp_dir!("amp_env_parity")
        args_file = Path.join(dir, "args.txt")

        amp_path =
          TestSupport.write_executable!(
            dir,
            "amp_env_stub",
            "#!/usr/bin/env bash\nset -euo pipefail\nif [ -n \"${AMP_TEST_ARGS_FILE:-}\" ]; then printf '%s\\n' \"$@\" > \"$AMP_TEST_ARGS_FILE\"; fi\necho ${AMP_VALID_ALPHA:-missing}\n"
          )

        try do
          TestSupport.with_env(
            %{"AMP_CLI_PATH" => amp_path, "AMP_TEST_ARGS_FILE" => args_file},
            fn ->
              assert {:ok, "one"} = AmpSdk.Command.run(["threads", "list"])
              assert File.read!(args_file) == "threads\nlist\n"
            end
          )
        after
          File.rm_rf(dir)
        end
      end
    )
  end
end
