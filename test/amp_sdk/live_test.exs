defmodule AmpSdk.LiveTest do
  use ExUnit.Case, async: false

  @moduletag :live

  alias AmpSdk.Types.{Options, ResultMessage, SystemMessage, ThinkingContent}

  describe "execute/2 with real CLI" do
    @tag timeout: 60_000
    test "streams messages from amp" do
      messages =
        AmpSdk.execute("Respond with only: hello", %Options{dangerously_allow_all: true})
        |> Enum.to_list()

      assert length(messages) >= 2

      system_msgs = Enum.filter(messages, &match?(%SystemMessage{}, &1))
      assert system_msgs != []

      result_msgs = Enum.filter(messages, &match?(%ResultMessage{}, &1))
      assert length(result_msgs) == 1

      [result] = result_msgs
      assert result.result =~ ~r/hello/i
    end

    @tag timeout: 60_000
    test "surfaces stderr when CLI rejects mode" do
      result =
        AmpSdk.execute("hello", %Options{mode: "rush", dangerously_allow_all: true})
        |> Enum.to_list()

      error_msgs = Enum.filter(result, &match?(%AmpSdk.Types.ErrorResultMessage{}, &1))
      assert error_msgs != []
      [error] = error_msgs
      assert error.error =~ ~r/rush|not permitted|stream/i
    end
  end

  describe "execute with thinking" do
    @tag timeout: 60_000
    test "receives thinking content blocks" do
      messages =
        AmpSdk.execute("What is 2+2? Reply only the number.", %Options{
          thinking: true,
          dangerously_allow_all: true
        })
        |> Enum.to_list()

      assistant_msgs =
        Enum.filter(messages, &match?(%AmpSdk.Types.AssistantMessage{}, &1))

      thinking_blocks =
        assistant_msgs
        |> Enum.flat_map(fn %{message: %{content: content}} -> content end)
        |> Enum.filter(&match?(%ThinkingContent{}, &1))

      assert thinking_blocks != []
    end
  end

  describe "run/2 with real CLI" do
    @tag timeout: 60_000
    test "returns final result" do
      assert {:ok, result} =
               AmpSdk.run("What is 1+1? Reply only the number.", %Options{
                 dangerously_allow_all: true
               })

      assert result =~ "2"
    end

    @tag timeout: 60_000
    test "returns error for rush mode" do
      assert {:error, error} = AmpSdk.run("hello", %Options{mode: "rush"})
      assert %AmpSdk.Error{} = error
      assert error.message =~ ~r/rush|not permitted|stream/i
    end
  end

  describe "threads with real CLI" do
    @tag timeout: 30_000
    test "creates a new thread" do
      assert {:ok, thread_id} = AmpSdk.threads_new(visibility: :private)
      assert is_binary(thread_id)
      assert String.starts_with?(thread_id, "T-")
    end

    @tag timeout: 30_000
    test "lists threads" do
      assert {:ok, output} = AmpSdk.threads_list()
      assert is_binary(output)
    end
  end

  describe "tools with real CLI" do
    @tag timeout: 30_000
    test "lists tools" do
      assert {:ok, output} = AmpSdk.tools_list()
      assert output =~ "Bash"
      assert output =~ "Read"
    end

    @tag timeout: 30_000
    test "shows tool details" do
      assert {:ok, output} = AmpSdk.tools_show("Read")
      assert is_binary(output)
    end
  end

  describe "usage with real CLI" do
    @tag timeout: 30_000
    test "returns credit info" do
      assert {:ok, output} = AmpSdk.usage()
      assert output =~ ~r/remaining|credits|usage/i
    end
  end
end
