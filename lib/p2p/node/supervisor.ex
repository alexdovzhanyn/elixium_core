defmodule Elixium.Node.Supervisor do
  alias Elixium.Store.Oracle
  use Supervisor
  require Logger

  @moduledoc """
    Responsible for getting peer information and launching connection handlers
  """

  @default_port 31_013

  def start_link, do: start_link(self(), @default_port)
  def start_link([router_pid]) when is_pid(router_pid), do: start_link(router_pid, @default_port)
  def start_link([port]) when is_number(port), do: start_link(self(), port)
  def start_link([nil]), do: start_link(self(), @default_port)
  def start_link([router_pid, nil]), do: start_link(router_pid, @default_port)
  def start_link([router_pid, port]), do: start_link(router_pid, port)

  def start_link(router_pid, port) do
    Supervisor.start_link(__MODULE__, [router_pid, port], name: __MODULE__)
  end

  def init([router_pid, port]) do
    Oracle.start_link(Elixium.Store.Peer)
    :pg2.create(:p2p_handlers)

    case open_socket(port) do
      :error -> :error
      socket ->
        # Fetch known peers. We're going to try to connect to them
        # before setting up a listener
        peers = find_potential_peers(port)

        handlers = generate_handlers(socket, router_pid, peers)

        children = handlers ++ [Elixium.HostAvailability.Supervisor]

        Supervisor.init(children, strategy: :one_for_one)
    end
  end

  defp generate_handlers(socket, router_pid, peers) do
    for i <- 1..10 do
      %{
        id: :"ConnectionHandler#{i}",
        start: {
          Elixium.Node.ConnectionHandler,
          :start_link,
          [socket, router_pid, peers, i]
        },
        type: :worker,
        restart: :permanent
      }
    end
  end

  @spec open_socket(pid) :: pid | :error
  defp open_socket(port) do
    options = [:binary, reuseaddr: true, active: false]

    case :gen_tcp.listen(port, options) do
      {:ok, socket} ->
        Logger.info("Opened listener socket on port #{port}.")
        socket
      _ ->
        Logger.warn("Listen socket not started, something went wrong.")
        :error
    end
  end

  # Either loads peers from a local storage or connects to the
  # bootstrapping registry
  @spec find_potential_peers(integer) :: List | :not_found
  defp find_potential_peers(port) do
    case Oracle.inquire(:"Elixir.Elixium.Store.PeerOracle", {:load_known_peers, []}) do
      [] -> fetch_peers_from_registry(port)
      peers -> peers
    end
  end


  # Connects to the bootstrapping peer registry and returns a list of
  # previously connected peers.
  @spec fetch_peers_from_registry(integer) :: List
  def fetch_peers_from_registry(port_conf) do
    url = Application.get_env(:elixium_core, :registry_url)
    own_local_ip = fetch_local_ip
    own_public_ip = fetch_public_ip["ip"]
    case :httpc.request(url ++ '/' ++ Integer.to_charlist(port_conf)) do
      {:ok, {{'HTTP/1.1', 200, 'OK'}, _headers, body}} ->
        peers =
          body
          |> Jason.decode!()
          |> Enum.map(&peerstring_to_tuple/1)
          |> Enum.filter(fn {peer, port} ->
            port != nil &&
            validate_own_ip_port(peer, own_local_ip, port, port_conf) == false &&
            validate_own_ip_port(peer, own_public_ip, port, port_conf) == false
          end)

        if peers == [], do: :not_found, else: peers

      {:error, _} -> :not_found
    end
  end


  @doc """
    On Connection, fetch our public ip
  """
  @spec fetch_public_ip :: String.t()
  def fetch_public_ip do
   api_url =  'https://api.ipify.org?format=json'
   case :httpc.request(api_url) do
     {:ok, {{'HTTP/1.1', 200, 'OK'}, _headers, body}} ->
         body
         |> Jason.decode!()
     {:error, _} -> :not_found
   end
  end

  @doc """
    On Connection, fetch our local ip
  """
  @spec fetch_local_ip() :: String.t()
  def fetch_local_ip do
    {:ok, [_, {_, ip_list}]} = :inet.getifaddrs()
    ip_list[:addr]
    |> :inet_parse.ntoa()
  end

  @doc """
    Checks Ip address & port match
  """
  @spec fetch_local_ip() :: String.t()
  def validate_own_ip_port(peer, ip, port, port_conf) do
    if peer !== ip && port !== port_conf do
      false
    else
      true
    end
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
