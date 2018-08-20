defmodule Elixium.P2P.Peer do
  alias Elixium.P2P.ConnectionHandler

  def initialize(port \\ 31_013) do
    IO.puts("Starting listener socket on port #{port}.")

    {:ok, supervisor} =
      port
      |> start_listener()
      |> generate_handlers()
      |> Supervisor.start_link(strategy: :one_for_one)
  end

  defp start_listener(port) do
    options = [:binary, reuseaddr: true, active: false]

    case :gen_tcp.listen(port, options) do
      {:ok, socket} -> socket
      _ -> IO.puts("Listen socket not started, something went wrong.")
    end
  end

  defp generate_handlers(socket, count \\ 10) do
    for _ <- 1..count do
      %{
        id: 2 |> :crypto.strong_rand_bytes() |> Base.encode16(),
        start: {ConnectionHandler, :start_link, [socket, self()]},
        type: :worker
      }
    end
  end
end
