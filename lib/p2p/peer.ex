defmodule Elixium.P2P.Peer do
  alias Elixium.Store.Oracle
  require Logger

  @testnet_url 'https://registry.testnet.elixium.app/'
  @default_port 31_013

  @moduledoc """
    Contains functionality for communicating with other peers
  """

  def initialize, do: initialize(self(), @default_port)
  def initialize(pid) when is_pid(pid), do: initialize(pid, @default_port)
  def initialize(port) when is_number(port), do: initialize(self(), port)

  @spec initialize(pid, integer) :: pid
  def initialize(comm_pid, port) do
    Logger.info("Starting listener socket on port #{port}.")

    {:ok, supervisor} =
      port
      |> start_listener()
      |> generate_handlers(port, comm_pid)
      |> Supervisor.start_link(strategy: :one_for_one)

    supervisor
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

  # Opens a socket listening on the given port
  defp start_listener(port) do
    options = [:binary, reuseaddr: true, active: false]

    case :gen_tcp.listen(port, options) do
      {:ok, socket} -> socket
      _ -> Logger.warn("Listen socket not started, something went wrong.")
    end
  end

  # Starts multiple "handler" processes that will asynchronously process
  # requests on a given socket.
  defp generate_handlers(socket, port, comm_pid, count \\ 10) do
    {:ok, oracle} = Oracle.start_link(Elixium.Store.Peer)
    # Fetch known peers. We're going to try to connect to them
    # before setting up a listener
    peers = find_potential_peers(port, oracle)

    for i <- 1..count do
      %{
        id: "peer_handler_#{i}",
        start: {
          Elixium.P2P.ConnectionHandler,
          :start_link,
          [socket, comm_pid, peers, i, oracle]
        },
        type: :worker,
        name: "peer_handler_#{i}"
      }
    end
  end

  # Either loads peers from a local storage or connects to the
  # bootstrapping registry
  @spec find_potential_peers(integer, pid) :: List | :not_found
  defp find_potential_peers(port, oracle) do
    case Oracle.inquire(oracle, {:load_known_peers, []}) do
      :not_found -> fetch_peers_from_registry(port)
      peers -> peers
    end
  end

  # Connects to the bootstrapping peer registry and returns a list of
  # previously connected peers.
  @spec fetch_peers_from_registry(integer) :: List
  defp fetch_peers_from_registry(port) do
    case :httpc.request(@testnet_url ++ '/' ++ Integer.to_charlist(port)) do
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

  # Converts from a colon delimited string to a tuple containing the
  # ip and port. "127.0.0.1:3000" becomes {'127.0.0.1', 3000}
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

end
