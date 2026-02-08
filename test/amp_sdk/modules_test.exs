defmodule AmpSdk.ModulesTest do
  use ExUnit.Case, async: true

  @modules [
    {AmpSdk.Tools, [{:list, 0}, {:show, 1}, {:use, 1}, {:use, 2}, {:make, 1}, {:make, 2}]},
    {AmpSdk.Tasks, [{:list, 0}, {:import_tasks, 1}, {:import_tasks, 2}]},
    {AmpSdk.Review, [{:run, 0}, {:run, 1}]},
    {AmpSdk.Skills, [{:add, 1}, {:list, 0}, {:remove, 1}, {:info, 1}]},
    {AmpSdk.Permissions,
     [
       {:list, 0},
       {:list, 1},
       {:list_raw, 0},
       {:list_raw, 1},
       {:test, 1},
       {:test, 2},
       {:add, 2},
       {:add, 3}
     ]},
    {AmpSdk.MCP,
     [
       {:add, 2},
       {:add, 3},
       {:list, 0},
       {:list, 1},
       {:list_raw, 0},
       {:list_raw, 1},
       {:remove, 1},
       {:doctor, 0},
       {:approve, 1},
       {:oauth_login, 1},
       {:oauth_login, 2},
       {:oauth_logout, 1},
       {:oauth_logout, 2},
       {:oauth_status, 1},
       {:oauth_status, 2}
     ]},
    {AmpSdk.Usage, [{:info, 0}]},
    {AmpSdk.Threads,
     [
       {:new, 0},
       {:new, 1},
       {:markdown, 1},
       {:list, 0},
       {:list, 1},
       {:list_raw, 0},
       {:list_raw, 1},
       {:search, 1},
       {:search, 2},
       {:share, 1},
       {:rename, 2},
       {:archive, 1},
       {:delete, 1},
       {:handoff, 1},
       {:handoff, 2},
       {:replay, 1},
       {:replay, 2}
     ]}
  ]

  for {mod, funs} <- @modules do
    describe "#{inspect(mod)}" do
      for {fun, arity} <- funs do
        test "exports #{fun}/#{arity}" do
          Code.ensure_loaded!(unquote(mod))
          assert function_exported?(unquote(mod), unquote(fun), unquote(arity))
        end
      end
    end
  end

  describe "AmpSdk delegates" do
    setup do
      Code.ensure_loaded!(AmpSdk)
      :ok
    end

    @delegates [
      {:tools_list, 0},
      {:tools_show, 1},
      {:tools_use, 1},
      {:tools_make, 1},
      {:tools_make, 2},
      {:review, 0},
      {:usage, 0},
      {:skills_list, 0},
      {:skills_add, 1},
      {:skills_remove, 1},
      {:skills_info, 1},
      {:mcp_list, 0},
      {:mcp_list, 1},
      {:mcp_list_raw, 0},
      {:mcp_list_raw, 1},
      {:mcp_remove, 1},
      {:mcp_doctor, 0},
      {:mcp_approve, 1},
      {:mcp_oauth_login, 1},
      {:mcp_oauth_login, 2},
      {:mcp_oauth_logout, 1},
      {:mcp_oauth_logout, 2},
      {:mcp_oauth_status, 1},
      {:mcp_oauth_status, 2},
      {:permissions_list, 0},
      {:permissions_list, 1},
      {:permissions_list_raw, 0},
      {:permissions_list_raw, 1},
      {:permissions_test, 1},
      {:permissions_add, 2},
      {:tasks_list, 0},
      {:tasks_import, 1},
      {:tasks_import, 2},
      {:threads_list, 0},
      {:threads_list, 1},
      {:threads_list_raw, 0},
      {:threads_list_raw, 1},
      {:threads_search, 1},
      {:threads_archive, 1},
      {:threads_share, 1},
      {:threads_rename, 2},
      {:threads_delete, 1},
      {:threads_handoff, 1},
      {:threads_handoff, 2},
      {:threads_replay, 1},
      {:threads_replay, 2},
      {:threads_new, 0},
      {:threads_markdown, 1}
    ]

    for {fun, arity} <- @delegates do
      test "#{fun}/#{arity} is delegated" do
        assert function_exported?(AmpSdk, unquote(fun), unquote(arity))
      end
    end
  end
end
