# List configured MCP servers
# Run with: mix run examples/mcp_list.exs

Code.require_file(Path.expand("support/example_helper.exs", __DIR__))

alias Examples.Support

Support.init!()

IO.puts("=== MCP Servers ===\n")

case AmpSdk.mcp_list(Support.command_opts()) do
  {:ok, servers} ->
    IO.puts("Found #{length(servers)} MCP server(s)\n")

    Enum.each(servers, fn server ->
      line = "#{server.name} [#{server.type}] source=#{server.source}"

      line =
        cond do
          is_binary(server.url) -> line <> " url=#{server.url}"
          is_binary(server.command) -> line <> " command=#{server.command}"
          true -> line
        end

      IO.puts(line)
    end)

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
end

System.halt(0)
