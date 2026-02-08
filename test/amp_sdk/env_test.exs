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

  test "Command.run injects AMP_SDK_VERSION and does not forward non-whitelisted env keys" do
    dir = TestSupport.tmp_dir!("amp_env_command_sdk_version")

    amp_path =
      TestSupport.write_executable!(
        dir,
        "amp_env_sdk_stub",
        "#!/usr/bin/env bash\nset -euo pipefail\necho \"${AMP_SDK_VERSION:-missing}|${NOT_AMP_KEY:-missing}|${AMP_VALID_ALPHA:-missing}\"\n"
      )

    try do
      TestSupport.with_env(
        %{
          "AMP_CLI_PATH" => amp_path,
          "NOT_AMP_KEY" => "blocked",
          "AMP_VALID_ALPHA" => "allowed"
        },
        fn ->
          assert {:ok, output} = AmpSdk.Command.run(["threads", "list"])

          [sdk_version, not_amp, amp_value] = String.split(output, "|", parts: 3)

          assert sdk_version == AmpSdk.Env.sdk_version_tag()
          assert not_amp == "missing"
          assert amp_value == "allowed"
        end
      )
    after
      File.rm_rf(dir)
    end
  end

  test "normalize_overrides drops nil values instead of stringifying them" do
    assert AmpSdk.Env.normalize_overrides(%{"AMP_ALPHA" => "one", "AMP_BETA" => nil}) ==
             %{"AMP_ALPHA" => "one"}

    assert AmpSdk.Env.normalize_overrides([{"AMP_ALPHA", "one"}, {"AMP_BETA", nil}]) ==
             %{"AMP_ALPHA" => "one"}
  end
end
