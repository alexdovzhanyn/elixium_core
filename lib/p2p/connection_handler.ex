defmodule Elixium.P2P.ConnectionHandler do
  alias Elixium.P2P.PeerStore
  alias Elixium.P2P.Authentication
  alias Elixium.P2P.GhostProtocol.Message
  require Logger

  @moduledoc """
    Manage inbound and outbound connections
  """

  @doc """
    Spawn a new handler, check to see if it knows of any possible peers. If there
    is a peer that it knows of, it will attempt a connection
    to that peer. If the connection fails or if it does
    not know of any peers, just sets up a listener and await
    an authentication message from another peer.
  """
  @spec start_link(reference, pid, List, integer) :: {:ok, pid}
  def start_link(socket, pid, peers, connection_index) do
    pid =
      case peers do
        :not_found ->
          Logger.warn("(Handler #{connection_index}): No known peers! Accepting inbound connections instead.")
          spawn_link(__MODULE__, :accept_inbound_connection, [socket, pid])

        peers ->
          if length(peers) >= connection_index do
            {ip, port} = Enum.at(peers, connection_index - 1)
            had_previous_connection = had_previous_connection?(ip)
            credentials = Authentication.load_credentials(ip)

            spawn_link(__MODULE__, :attempt_outbound_connection, [
              {ip, port},
              had_previous_connection,
              credentials,
              socket,
              pid
            ])
          else
            spawn_link(__MODULE__, :accept_inbound_connection, [socket, pid])
          end
      end

    {:ok, pid}
  end

  def attempt_outbound_connection(
        {ip, port},
        had_previous_connection,
        credentials,
        socket,
        master_pid
      ) do
    Logger.info("Attempting connection to peer at host: #{ip}, port: #{port}...")

    case :gen_tcp.connect(ip, port, [:binary, active: false], 1000) do
      {:ok, connection} ->
        Logger.info("Connected")

        shared_secret =
          if had_previous_connection do
            Authentication.outbound_peer(connection, credentials)
          else
            Authentication.outbound_new_peer(connection, credentials)
          end

        prepare_connection_loop(connection, shared_secret, master_pid)

      {:error, reason} ->
        Logger.warn("Error connecting to peer: #{reason}. Starting listener instead.")

        accept_inbound_connection(socket, master_pid)
    end
  end

  @doc """
    Accept an incoming connection from a peer and decide whether
    they are a new peer or someone we've talked to previously,
    and then authenticate them accordingly
  """
  @spec accept_inbound_connection(reference, pid) :: none
  def accept_inbound_connection(listen_socket, master_pid) do
    Logger.info("Waiting for connection...")
    {:ok, socket} = :gen_tcp.accept(listen_socket)

    Logger.info("Accepted potential handshake")

    handshake = Message.read(socket)

    # If the handshake message contains JUST an identifier, the peer
    # is signaling to us that they've talked to us before. We can try
    # to find them in the database. Otherwise, they should be passing
    # multiple pieces of data in this request, in effort to give us
    # the information we need in order to register them.
    shared_secret =
      case handshake do
        %{identifier: _, salt: _, prime: _} -> Authentication.inbound_new_peer(handshake, socket)
        %{identifier: identifier} -> Authentication.inbound_peer(identifier, socket)
      end

    prepare_connection_loop(socket, shared_secret, master_pid)
  end

  defp prepare_connection_loop(socket, shared_secret, master_pid) do
    session_key = generate_session_key(shared_secret)
    Logger.info("Authenticated with peer.")

    peername = get_peername(socket)

    # Set the connected flag so that the parent process knows we've connected
    # to a peer.
    Process.put(:connected, peername)

    handle_connection(socket, session_key, master_pid)
  end

  defp handle_connection(socket, session_key, master_pid) do
    peername = Process.get(:connected)
    # Accept TCP messages without blocking
    :inet.setopts(socket, active: :once)

    receive do
      # When receiving a message through TCP, send the data back to the parent
      # process so it can handle it however it wants
      {:tcp, _, data} ->
        message = Message.read(data, session_key)

        Logger.info("Accepted message from #{peername}")

        # Send out the message to the parent of this process (a.k.a the pid that
        # was passed in when calling start/2)
        send(master_pid, message)
        IO.inspect(message)

      # When receiving data from the parent process, send it to the network
      # through TCP
      message ->
        Logger.info("Sending data to peer: #{peername}")

        "DATA"
        |> Message.build(message, session_key)
        |> Message.send(socket)
    end

    handle_connection(socket, session_key, master_pid)
  end

  defp generate_session_key(shared_secret) do
    # Truncate the key to be 32 bytes (256 bits) since AES256 won't accept anything bigger.
    # Originally, I was worried this would be a security flaw, but according to
    # https://crypto.stackexchange.com/questions/3288/is-truncating-a-hashed-private-key-with-sha-1-safe-to-use-as-the-symmetric-key-f
    # it isn't
    <<session_key::binary-size(32)>> <> _ = shared_secret

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
