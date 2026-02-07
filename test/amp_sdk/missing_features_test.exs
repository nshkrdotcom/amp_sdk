defmodule AmpSdk.MissingFeaturesTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Types.Options

  describe "Options new flags" do
    test "no_ide defaults to false" do
      opts = struct!(Options, %{})
      assert Map.get(opts, :no_ide) == false
    end

    test "no_notifications defaults to false" do
      opts = struct!(Options, %{})
      assert Map.get(opts, :no_notifications) == false
    end

    test "no_color defaults to false" do
      opts = struct!(Options, %{})
      assert Map.get(opts, :no_color) == false
    end

    test "no_jetbrains defaults to false" do
      opts = struct!(Options, %{})
      assert Map.get(opts, :no_jetbrains) == false
    end

    test "flags can be set to true" do
      opts =
        struct!(Options, %{
          no_ide: true,
          no_notifications: true,
          no_color: true,
          no_jetbrains: true
        })

      assert opts.no_ide
      assert opts.no_notifications
      assert opts.no_color
      assert opts.no_jetbrains
    end
  end

  describe "build_args with new flags" do
    test "--no-ide when no_ide: true" do
      opts = struct!(Options, %{no_ide: true})
      args = AmpSdk.Stream.build_args(opts)
      assert "--no-ide" in args
    end

    test "no --no-ide when no_ide: false" do
      opts = struct!(Options, %{no_ide: false})
      args = AmpSdk.Stream.build_args(opts)
      refute "--no-ide" in args
    end

    test "--no-notifications when no_notifications: true" do
      opts = struct!(Options, %{no_notifications: true})
      args = AmpSdk.Stream.build_args(opts)
      assert "--no-notifications" in args
    end

    test "--no-color when no_color: true" do
      opts = struct!(Options, %{no_color: true})
      args = AmpSdk.Stream.build_args(opts)
      assert "--no-color" in args
    end

    test "--no-jetbrains when no_jetbrains: true" do
      opts = struct!(Options, %{no_jetbrains: true})
      args = AmpSdk.Stream.build_args(opts)
      assert "--no-jetbrains" in args
    end
  end

  describe "MCP OAuth functions" do
    test "oauth_login/2 is defined" do
      Code.ensure_loaded!(AmpSdk.MCP)
      assert function_exported?(AmpSdk.MCP, :oauth_login, 2)
    end

    test "oauth_logout/1 is defined" do
      Code.ensure_loaded!(AmpSdk.MCP)
      assert function_exported?(AmpSdk.MCP, :oauth_logout, 1)
    end

    test "oauth_status/1 is defined" do
      Code.ensure_loaded!(AmpSdk.MCP)
      assert function_exported?(AmpSdk.MCP, :oauth_status, 1)
    end
  end

  describe "AmpSdk MCP OAuth delegates" do
    setup do
      Code.ensure_loaded!(AmpSdk)
      :ok
    end

    test "mcp_oauth_login/2 is delegated" do
      assert function_exported?(AmpSdk, :mcp_oauth_login, 2)
    end

    test "mcp_oauth_logout/1 is delegated" do
      assert function_exported?(AmpSdk, :mcp_oauth_logout, 1)
    end

    test "mcp_oauth_status/1 is delegated" do
      assert function_exported?(AmpSdk, :mcp_oauth_status, 1)
    end
  end
end
