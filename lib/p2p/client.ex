defmodule Elixium.P2P.Client do
  require IEx
  alias Elixium.P2P.GhostProtocol.Parser
  alias Elixium.P2P.GhostProtocol.Message
  alias Elixium.P2P.PeerStore
  alias Elixium.Utilities

  def start(ip, port) do
    had_previous_connection = had_previous_connection?(ip)

    credentials =
      ip
      |> List.to_string()
      |> load_credentials()

    IO.write "Connecting to node at host: #{ip}, port: #{port}... "
    {:ok, peer} = :gen_tcp.connect(ip, port, [:binary, active: false])
    IO.puts "Connected"

    key = case had_previous_connection do
      false -> authenticate_new_peer(peer, credentials)
      true -> authenticate_peer(peer, credentials)
    end

    <<session_key :: binary-size(32)>> <> rest = key

    IO.puts "Authenticated with peer."

    handle_connection(peer, session_key)
  end

  def handle_connection(peer, session_key) do
    # {:ok, data} = :gen_tcp.recv(socket, 0)
    data = IO.gets "What is the data? "

    message =
      Message.build("DATA", %{ data: data })
      |> :erlang.term_to_binary()
      |> Utilities.pad(32)

    encrypted_message = :crypto.block_encrypt(:aes_ecb, session_key, message)

    :ok = :gen_tcp.send(peer, encrypted_message)

    # {generator, _} = Integer.parse(generator)
    # {:ok, server_public_value} = Base.decode64(server_public_value)
    # {:ok, private_client_session_key} = Strap.session_key(client, server_public_value)

    # IO.puts Base.encode64(private_client_session_key)


    handle_connection(peer, session_key)
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

    identifier = Base.encode64(identifier)

    handshake = Message.build("HANDSHAKE", %{
      prime: prime,
      generator: generator,
      salt: salt,
      verifier: verifier,
      public_value: public_value,
      identifier: identifier
    })

    :ok = :gen_tcp.send(peer, handshake)

    %{public_value: peer_public_value} =
      peer
      |> :gen_tcp.recv(0)
      |> Parser.parse()

    {:ok, peer_public_value} = Base.decode64(peer_public_value)
    {:ok, shared_master_key} = Strap.session_key(client, peer_public_value)

    shared_master_key
  end

  defp authenticate_peer(peer, {identifier, password}) do
    encoded_id = Base.encode64(identifier)
    handshake = Message.build("HANDSHAKE", %{identifier: encoded_id})
    :ok = :gen_tcp.send(peer, handshake)

    %{prime: prime, generator: generator, salt: salt, public_value: peer_public_value} =
      peer
      |> :gen_tcp.recv(0)
      |> Parser.parse()

    {:ok, peer_public_value} = Base.decode64(peer_public_value)

    client =
      Strap.protocol(:srp6a, prime, generator)
      |> Strap.client(identifier, password, salt)

    public_value =
      client
      |> Strap.public_value()
      |> Base.encode64()


    auth = Message.build("HANDSHAKE", %{public_value: public_value})
    :ok = :gen_tcp.send(peer, auth)

    {:ok, shared_master_key} = Strap.session_key(client, peer_public_value)

    shared_master_key
  end

  defp load_credentials(ip) do
    case PeerStore.load_self(ip) do
      :not_found -> generate_and_store_credentials(ip)
      {identifier, password} -> {identifier, password}
    end
  end

  defp generate_and_store_credentials(ip) do
    {identifier, password} = {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}
    PeerStore.save_self(identifier, password, ip)

    {identifier, password}
  end

  defp had_previous_connection?(ip) do
    case PeerStore.load_self(ip) do
      :not_found -> false
      {identifier, password} -> true
    end
  end
end
