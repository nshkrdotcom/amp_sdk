defmodule AmpSdk.ThreadsTest do
  use ExUnit.Case, async: true

  alias AmpSdk.Threads

  describe "module API" do
    test "new/1 is defined" do
      Code.ensure_loaded!(Threads)
      assert function_exported?(Threads, :new, 1)
    end

    test "markdown/1 is defined" do
      Code.ensure_loaded!(Threads)
      assert function_exported?(Threads, :markdown, 1)
    end
  end
end
