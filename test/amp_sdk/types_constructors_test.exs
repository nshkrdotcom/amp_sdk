defmodule AmpSdk.TypesConstructorsTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Error
  alias AmpSdk.Types.{MCPHttpServer, MCPStdioServer, Permission}

  test "Permission struct enforces required keys" do
    assert_raise ArgumentError, fn -> struct!(Permission, %{action: "ask"}) end
    assert_raise ArgumentError, fn -> struct!(Permission, %{tool: "Bash"}) end
  end

  test "Permission.new/3 returns typed error for invalid delegate options" do
    assert {:error, %Error{kind: :invalid_configuration}} = Permission.new("Bash", "delegate", [])
  end

  test "MCPStdioServer and MCPHttpServer enforce required keys" do
    assert_raise ArgumentError, fn -> struct!(MCPStdioServer, %{args: []}) end
    assert_raise ArgumentError, fn -> struct!(MCPHttpServer, %{headers: %{}}) end
  end

  test "MCP constructors validate required values" do
    assert {:error, %Error{kind: :invalid_configuration}} = MCPStdioServer.new(command: "")
    assert {:error, %Error{kind: :invalid_configuration}} = MCPHttpServer.new(url: "")

    assert {:ok, %MCPStdioServer{command: "npx"}} = MCPStdioServer.new(command: "npx")

    assert {:ok, %MCPHttpServer{url: "https://example.com"}} =
             MCPHttpServer.new(url: "https://example.com")
  end

  test "MCP constructors reject conflicting atom and string keys" do
    assert {:error, %Error{kind: :invalid_configuration, message: message}} =
             MCPStdioServer.new(%{:command => "npx", "command" => "node"})

    assert message =~ "conflicting values"

    assert {:error, %Error{kind: :invalid_configuration, message: message}} =
             MCPHttpServer.new(%{:url => "https://a.example", "url" => "https://b.example"})

    assert message =~ "conflicting values"
  end

  test "MCP constructors drop nil env/header values" do
    assert {:ok, %MCPStdioServer{env: env}} =
             MCPStdioServer.new(command: "npx", env: %{"A" => "1", "B" => nil})

    assert env == %{"A" => "1"}

    assert {:ok, %MCPHttpServer{headers: headers}} =
             MCPHttpServer.new(url: "https://example.com", headers: %{"A" => "1", "B" => nil})

    assert headers == %{"A" => "1"}
  end
end
