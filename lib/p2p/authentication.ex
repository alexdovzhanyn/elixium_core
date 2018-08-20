defmodule Elixium.P2P.Authentication do
  alias Elixium.P2P.GhostProtocol.Message
  alias Elixium.P2P.PeerStore

  @spec load_credentials(String.t()) :: {bitstring, bitstring}
  def load_credentials(ip) do
    ip = List.to_string(ip)

    case PeerStore.load_self(ip) do
      :not_found -> generate_and_store_credentials(ip)
      {identifier, password} -> {identifier, password}
    end
  end

  @spec generate_and_store_credentials(String.t()) :: {bitstring, bitstring}
  defp generate_and_store_credentials(ip) do
    {identifier, password} = {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}
    PeerStore.save_self(identifier, password, ip)

    {identifier, password}
  end

  # If this node has never communicated with a given peer, it will first
  # need to identify itself.
  @spec outbound_new_peer(reference, {bitstring, bitstring}) :: bitstring
  def outbound_new_peer(peer, {identifier, password}) do
    {prime, generator} = Strap.prime_group(1024)
    prime = Base.encode64(prime)

    salt =
      32
      |> :crypto.strong_rand_bytes()
      |> Base.encode64()

    client =
      :srp6a
      |> Strap.protocol(prime, generator)
      |> Strap.client(identifier, password, salt)

    verifier =
      client
      |> Strap.verifier()
      |> Base.encode64()

    public_value =
      client
      |> Strap.public_value()
      |> Base.encode64()

    identifier = Base.encode64(identifier)

    "HANDSHAKE"
    |> Message.build(%{
      prime: prime,
      generator: generator,
      salt: salt,
      verifier: verifier,
      public_value: public_value,
      identifier: identifier
    })
    |> Message.send(peer)

    %{public_value: peer_public_value} = Message.read(peer)

    {:ok, peer_public_value} = Base.decode64(peer_public_value)
    {:ok, shared_master_key} = Strap.session_key(client, peer_public_value)

    shared_master_key
  end

  @spec outbound_peer(reference, {bitstring, bitstring}) :: bitstring
  def outbound_peer(peer, {identifier, password}) do
    encoded_id = Base.encode64(identifier)

    "HANDSHAKE"
    |> Message.build(%{identifier: encoded_id})
    |> Message.send(peer)

    %{prime: prime, generator: generator, salt: salt, public_value: peer_public_value} =
      Message.read(peer)

    {:ok, peer_public_value} = Base.decode64(peer_public_value)

    client =
      Strap.protocol(:srp6a, prime, generator)
      |> Strap.client(identifier, password, salt)

    public_value =
      client
      |> Strap.public_value()
      |> Base.encode64()

    "HANDSHAKE"
    |> Message.build(%{public_value: public_value})
    |> Message.send(peer)

    {:ok, shared_master_key} = Strap.session_key(client, peer_public_value)

    shared_master_key
  end
end
