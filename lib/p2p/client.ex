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
      |> Strap.client("Alex", "thepass", salt)

    client_verifier =
      Strap.verifier(client)
      |> Base.encode64()

    client_public_value =
      client
      |> Strap.public_value()
      |> Base.encode64()


    auth = Message.build("HANDSHAKE", %{
      prime: prime,
      generator: Integer.to_string(generator),
      salt: salt,
      client_verifier: client_verifier,
      client_public_value: client_public_value
    })

    :ok = :gen_tcp.send(peer, auth)
    {:ok, response} = :gen_tcp.recv(peer, 0)

    [prime, generator, salt, server_public_value] = String.split(response, "|")
    {:ok, server_public_value} = Base.decode64(server_public_value)

    {:ok, private_client_session_key} = Strap.session_key(client, server_public_value)

    IO.puts Base.encode64(private_client_session_key)
  end
end
