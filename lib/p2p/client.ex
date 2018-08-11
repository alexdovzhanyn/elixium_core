defmodule Elixium.P2P.Client do
  require IEx
  alias Elixium.P2P.GhostProtocol.Parser
  alias Elixium.P2P.GhostProtocol.Message
  alias Elixium.P2P.PeerStore

  def start(ip, port) do
    credentials = load_credentials()

    IO.write "Connecting to node at host: #{ip}, port: #{port}... "
    {:ok, peer} = :gen_tcp.connect(ip, port, [:binary, active: false])
    IO.puts "Connected"

    new_connection = true

    session_key = if new_connection do
      authenticate_new_peer(peer, credentials)
    else
      authenticate_peer(peer, credentials)
    end

    handle_connection(peer, session_key)
  end

  def handle_connection(peer, credentials) do
    # {:ok, data} = :gen_tcp.recv(socket, 0)


    # {generator, _} = Integer.parse(generator)
    # {:ok, server_public_value} = Base.decode64(server_public_value)
    # {:ok, private_client_session_key} = Strap.session_key(client, server_public_value)

    # IO.puts Base.encode64(private_client_session_key)


    handle_connection(peer, credentials)
  end

  # If this node has never communicated with a given peer, it will first
  # need to identify itself.
  defp authenticate_new_peer(peer, {identifier, password}) do
    {prime, generator} = Strap.prime_group(1024)

    prime = Base.encode64(prime)

    salt =
      :crypto.strong_rand_bytes(32)
      |> Base.encode64

    client =
      Strap.protocol(:srp6a, prime, generator)
      |> Strap.client(identifier, password, salt)

    verifier =
      Strap.verifier(client)
      |> Base.encode64()

    public_value =
      client
      |> Strap.public_value()
      |> Base.encode64()


    handshake = Message.build("HANDSHAKE", %{
      prime: prime,
      generator: generator,
      salt: salt,
      verifier: verifier,
      public_value: public_value
    })

    :ok = :gen_tcp.send(peer, handshake)

    %{public_value: peer_public_value} =
      peer
      |> :gen_tcp.recv(0)
      |> Parser.parse()

    {:ok, peer_public_value} = Base.decode64(peer_public_value)

    {:ok, shared_master_key} = Strap.session_key(client, peer_public_value)

    IO.puts Base.encode64(shared_master_key)

    IO.puts "Authenticated with peer."

    shared_master_key
  end

  defp authenticate_peer(peer, {identifier, password}) do
    IO.puts "shouldnt be here yet"
  end

  defp load_credentials do
    case PeerStore.load_self() do
      :not_found -> generate_and_store_credentials()
      {identifier, password} -> {identifier, password}
    end
  end

  defp generate_and_store_credentials do
    {identifier, password} = {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}
    PeerStore.save_self(identifier, password)

    {identifier, password}
  end
end
