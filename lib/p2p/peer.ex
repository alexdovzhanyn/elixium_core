defmodule Elixium.P2P.Peer do
  alias Elixium.Store.Oracle
  require Logger

  @default_port 31_013



  @moduledoc """
    Contains functionality for communicating with other peers
  """

  def initialize, do: initialize(self(), @default_port)
  def initialize(pid) when is_pid(pid), do: initialize(pid, @default_port)
  def initialize(port) when is_number(port), do: initialize(self(), port)

  @spec initialize(pid, integer) :: none
  def initialize(comm_pid, port) do
    Logger.info("Starting listener socket on port #{port}.")

    :pg2.create(:p2p_handlers)

    port
    |> start_listener()
    |> generate_handlers(port, comm_pid)
    |> Supervisor.start_link(strategy: :one_for_one, name: :peer_supervisor, max_restarts: 20)

    Elixium.HostAvailability.Supervisor.start_link()
  end

  @doc """
    Given a peer supervisor, return a list of all the
    handlers that are currently connected to another peer
  """
  @spec connected_handlers :: List
  def connected_handlers do
    :p2p_handlers
    |> :pg2.get_members()
    |> Enum.filter(fn p ->
        p
        |> Process.info()
        |> Keyword.get(:dictionary)
        |> Keyword.has_key?(:connected)
      end)
  end

  @doc """
    Broadcast a message to all peers
  """
  @spec gossip(String.t(), map) :: none
  def gossip(type, message) do
    Enum.each(connected_handlers(), &(send(&1, {type, message})))
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
        id: String.to_atom("peer_handler_#{i}"),
        start: {
          Elixium.P2P.ConnectionHandler,
          :start_link,
          [socket, comm_pid, peers, i, oracle]
        },
        type: :worker,
        restart: :permanent
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
  def fetch_peers_from_registry(port) do
    url = Application.get_env(:elixium_core, :registry_url)

    case :httpc.request(url ++ '/' ++ Integer.to_charlist(port)) do
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

  #  if Mix.env == :dev do
  #    {'localhost', port}
  #  else
      {ip, port}
  #  end
  end

end
