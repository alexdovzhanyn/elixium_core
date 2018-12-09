defmodule Elixium.P2P.Authentication do
  alias Elixium.P2P.GhostProtocol.Message

  @moduledoc """
    SRP authentication handshakes and generation of credentials
  """

  # If this node has never communicated with a given peer, it will first
  # need to identify itself.
  @spec outbound_auth(reference) :: bitstring
  def outbound_auth(peer) do
    {prime, generator} = Strap.prime_group(1024)
    identifier = :crypto.strong_rand_bytes(32)
    password = :crypto.strong_rand_bytes(32)
    salt = :crypto.strong_rand_bytes(32)

    client =
      :srp6a
      |> Strap.protocol(prime, generator)
      |> Strap.client(identifier, password, salt)

    "HANDSHAKE"
    |> Message.build(%{
         prime: prime,
         generator: generator,
         verifier: Strap.verifier(client),
         public_value: Strap.public_value(client)
       })
    |> Message.send(peer)

    %{public_value: peer_public_value} = Message.read(peer)

    {:ok, shared_master_key} = Strap.session_key(client, peer_public_value)

    shared_master_key
  end

  @spec inbound_auth(map, reference) :: bitstring
  def inbound_auth(message, socket) do
    %{
      public_value: peer_public_value,
      generator: generator,
      prime: prime,
      verifier: peer_verifier
    } = message

    server =
      :srp6a
      |> Strap.protocol(prime, generator)
      |> Strap.server(peer_verifier)

    "HANDSHAKE_AUTH"
    |> Message.build(%{public_value: Strap.public_value(server)})
    |> Message.send(socket)

    {:ok, shared_master_key} = Strap.session_key(server, peer_public_value)

    shared_master_key
  end
end
