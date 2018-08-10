defmodule Elixium.P2P.Client do
  require IEx
  alias Elixium.P2P.GhostProtocol.Parser
  alias Elixium.P2P.GhostProtocol.Message

  def start(ip, port) do
    IO.write "Connecting to node at host: #{ip}, port: #{port}... "
    {:ok, peer} = :gen_tcp.connect(ip, port, [:binary, active: false])
    IO.puts "Connected"

    handle_connection(peer)
  end

  def handle_connection(peer) do
    # {:ok, data} = :gen_tcp.recv(socket, 0)


    # {generator, _} = Integer.parse(generator)
    # {:ok, server_public_value} = Base.decode64(server_public_value)
    # {:ok, private_client_session_key} = Strap.session_key(client, server_public_value)

    # IO.puts Base.encode64(private_client_session_key)
    authenticate_new_peer(peer)

    handle_connection(peer)
  end

  # If this node has never communicated with a given peer, it will first
  # need to identify itself.
  defp authenticate_new_peer(peer) do
    {prime, generator} = Strap.prime_group(1024)

    prime = Base.encode64(prime)

    salt =
      :crypto.strong_rand_bytes(32)
      |> Base.encode64

    client =
      Strap.protocol(:srp6a, prime, generator)
      |> Strap.client("Ale", "thepass", salt)

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

    IO.puts "Authenticated with peer."
  end
end
