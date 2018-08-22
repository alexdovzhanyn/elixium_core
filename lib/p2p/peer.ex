defmodule Elixium.P2P.Peer do
  alias Elixium.P2P.ConnectionHandler
  alias Elixium.P2P.PeerStore

  @moduledoc """
    Contains functionality for communicating with other peers
  """

  @spec initialize(integer) :: pid
  def initialize(port \\ 31_013) do
    IO.puts("Starting listener socket on port #{port}.")

    {:ok, supervisor} =
      port
      |> start_listener()
      |> generate_handlers()
      |> Supervisor.start_link(strategy: :one_for_one)

    supervisor
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

    for i <- 1..count do
      %{
        id: "peer_handler_#{i}",
        start: {ConnectionHandler, :start_link, [socket, self(), peers, i]},
        type: :worker,
        name: "peer_handler_#{i}"
      }
    end
  end

  # Either loads peers from a local storage or connects to the
  # bootstrapping registry
  @spec find_potential_peers :: List | :not_found
  defp find_potential_peers do
    case PeerStore.load_known_peers() do
      :not_found -> fetch_peers_from_registry()
      peers -> peers
    end
  end

  # Connects to the bootstrapping peer registry and returns a list of
  # previously connected peers.
  @spec fetch_peers_from_registry :: List
  defp fetch_peers_from_registry do
    case :httpc.request(
           'http://testnet-peer-registry.w3tqcgzmeb.us-west-2.elasticbeanstalk.com/31013'
         ) do
      {:ok, {{'HTTP/1.1', 200, 'OK'}, _headers, body}} ->
        peers =
          body
          |> Jason.decode!()
          |> Enum.map(&peerstring_to_tuple(&1))
          |> Enum.filter(fn {_, port} -> port != nil end)

        if peers == [] do
          :not_found
        else
          peers
        end

      {:error, _} ->
        :not_found
    end
  end

  defp peerstring_to_tuple(peer) do
    [ip, port] = String.split(peer, ":")
    ip = String.to_charlist(ip)

    port =
      case Integer.parse(port) do
        {port, _} -> port
        :error -> nil
      end

    {ip, port}
  end

  @doc """
    Given a peer supervisor, return a list of all the
    handlers that are currently connected to another peer
  """
  @spec connected_handlers(pid) :: List
  def connected_handlers(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.filter(fn {_, p, _, _} ->
        dictionary =
          p
          |> Process.info()
          |> Keyword.get(:dictionary)

        match?([connected: _], dictionary)
      end)
    |> Enum.map(fn {_, p, _, _} -> p end)
  end

end
