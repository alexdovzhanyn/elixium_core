defmodule Elixium.P2P.Peer do
  alias Elixium.P2P.ConnectionHandler
  alias Elixium.P2P.PeerStore

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
    # Fetch known peers. We're going to try to connect to them
    # before setting up a listener
    peers = find_potential_peers()

    for _ <- 1..count do
      %{
        id: 2 |> :crypto.strong_rand_bytes() |> Base.encode16(),
        start: {ConnectionHandler, :start_link, [socket, self(), peers]},
        type: :worker
      }
    end
  end

  # Either loads peers from a local storage or connects to the
  # bootstrapping registry
  @spec find_potential_peers :: List | :not_found
  defp find_potential_peers do
    case PeerStore.load_known_peers do
      :not_found -> fetch_peers_from_registry
      peers -> peers
    end
  end

  # Connects to the bootstrapping peer registry and returns a list of
  # previously connected peers.
  @spec fetch_peers_from_registry :: List
  defp fetch_peers_from_registry do
    case :httpc.request('http://testnet-peer-registry.w3tqcgzmeb.us-west-2.elasticbeanstalk.com/31013') do
      {:ok, {{'HTTP/1.1', 200, 'OK'}, _headers, body}} ->
        peers =
          body
          |> Jason.decode!()
          |> Enum.map(fn p ->
            [ip, port] = String.split(p, ":")
            {port, _} = Integer.parse(port)
            ip = String.to_charlist(ip)

            {ip, port}
          end)

        if List.length(peers) == 0 do
          :not_found
        else
          peers
        end

      {:error, _} -> :not_found
    end
  end
end
