defmodule Elixium.P2P.ConnectionHandler do
  alias Elixium.P2P.PeerStore
  alias Elixium.P2P.Authentication
  alias Elixium.P2P.GhostProtocol.Message
  require IEx

  @doc """
    Spawn a new handler, and have it run the authentication code immediately
  """
  @spec start_link(reference, pid) :: {:ok, pid}
  def start_link(socket, pid) do
    # Fetch known peers. We're going to try to connect to them
    # before setting up a listener
    peers = [{'localhost', 11111}]
    # peers = PeerStore.load_known_peers

    pid =
      case peers do
        :not_found ->
          IO.puts("not found")

        peers ->
          {ip, port} = Enum.random(peers)
          had_previous_connection = had_previous_connection?(ip)
          credentials = Authentication.load_credentials(ip)
          spawn_link(__MODULE__, :attempt_outbound_connection, [{ip, port}, had_previous_connection, credentials, socket, pid])
      end

    {:ok, pid}
  end

  @doc """
    Checks to see if it knows of any possible peers. If there
    is a peer that it knows of, it will attempt a connection
    to that peer. If the connection fails or if it does
    not know of any peers, just sets up a listener and await
    an authentication message from another peer.
  """
  def create_connection(socket, master_pid, :not_found) do
    # Uh oh, no known peers!
    IO.puts("ji")
  end

  def attempt_outbound_connection({ip, port}, had_previous_connection, credentials, socket, master_pid) do
    IO.write "Attempting connection to peer at host: #{ip}, port: #{port}..."

    case :gen_tcp.connect(ip, port, [:binary, active: false], 1000) do
      {:ok, connection} ->
        IO.puts("Connected")

        # TODO change this later
        shared_secret =
          if had_previous_connection do
            Authentication.outbound_new_peer(connection, credentials)
          else
            Authentication.outbound_peer(connection, credentials)
          end

        prepare_connection_loop(connection, shared_secret, master_pid)

      {:error, reason} ->
        IO.puts("Error connecting to peer: #{reason}")
        # TODO: If it cant connect to a peer, start listening
        Process.sleep(:infinity)
    end
  end

  defp prepare_connection_loop(socket, shared_secret, master_pid) do
    session_key = generate_session_key(shared_secret)
    IO.puts("Authenticated with peer.")

    peername = get_peername(socket)

    # Set the connected flag so that the parent process knows we've connected
    # to a peer.
    Process.put(:connected, peername)

    handle_connection(socket, session_key, master_pid)
  end

  defp handle_connection(socket, session_key, master_pid) do
    IO.puts("HANDLE CONNECTION")
    IO.inspect(self())
    peername = Process.get(:connected)
    # Accept TCP messages without blocking
    :inet.setopts(socket, active: :once)

    receive do
      # When receiving a message through TCP, send the data back to the parent
      # process so it can handle it however it wants
      {:tcp, _, data} ->
        message = Message.read(data, session_key)

        IO.puts("Accepted message from #{peername}")

        # Send out the message to the parent of this process (a.k.a the pid that
        # was passed in when calling start/2)
        send(master_pid, message)
        IO.inspect(message)

      # When receiving data from the parent process, send it to the network
      # through TCP
      message ->
        IO.inspect(message)
        IO.puts("Sending data to peer: #{peername}")

        "DATA"
        |> Message.build(message, session_key)
        |> Message.send(socket)
    end

    handle_connection(socket, session_key, master_pid)
  end

  defp generate_session_key(shared_secret) do
    <<session_key::binary-size(32)>> <> _ = shared_secret

    IO.puts(session_key |> Base.encode64())

    session_key
  end

  @spec get_peername(reference) :: String.t()
  defp get_peername(socket) do
    {:ok, {addr, _port}} = :inet.peername(socket)

    addr
    |> :inet_parse.ntoa()
    |> to_string()
  end

  @spec had_previous_connection?(String.t()) :: boolean
  defp had_previous_connection?(ip) do
    case PeerStore.load_self(ip) do
      :not_found -> false
      {_identifier, _password} -> true
    end
  end
end
