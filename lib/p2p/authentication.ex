defmodule Elixium.P2P.Authentication do
  alias Elixium.P2P.GhostProtocol.Message
  alias Elixium.Store.Oracle

  @moduledoc """
    SRP authentication handshakes and generation of credentials
  """

  @spec load_credentials(String.t(), integer, pid) :: {bitstring, bitstring}
  def load_credentials(ip, port, peer_oracle) do
    ip = List.to_string(ip) <> ":" <> Integer.to_string(port)

    case Oracle.inquire(peer_oracle, {:load_self, [ip]}) do
      :not_found -> generate_and_store_credentials(ip, peer_oracle)
      {identifier, password} -> {identifier, password}
    end
  end

  @spec generate_and_store_credentials(String.t(), pid) :: {bitstring, bitstring}
  defp generate_and_store_credentials(ip, peer_oracle) do
    {identifier, password} = {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}
    Oracle.inquire(peer_oracle, {:save_self, [identifier, password, ip]})

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
    |> Message.send(peer) |> IO.inspect

    %{public_value: peer_public_value} = Message.read(peer)

    {:ok, peer_public_value} = Base.decode64(peer_public_value)
    {:ok, shared_master_key} = Strap.session_key(client, peer_public_value)

    shared_master_key
  end

  # Handle incoming authentication messages from peers, and save their
  # identity to the database for later
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

  @spec inbound_new_peer(map, reference, pid) :: bitstring
  def inbound_new_peer(message, socket, peer_oracle) do
    %{
      public_value: peer_public_value,
      generator: generator,
      prime: prime,
      verifier: peer_verifier,
      salt: salt,
      identifier: peer_identifier
    } = message

    {:ok, peer_verifier} = Base.decode64(peer_verifier)
    {:ok, peer_public_value} = Base.decode64(peer_public_value)

    server =
      :srp6a
      |> Strap.protocol(prime, generator)
      |> Strap.server(peer_verifier)

    server_public_value =
      server
      |> Strap.public_value()
      |> Base.encode64()

    "HANDSHAKE_AUTH"
    |> Message.build(%{public_value: server_public_value})
    |> Message.send(socket)

    {:ok, shared_master_key} = Strap.session_key(server, peer_public_value)

    # Now that we've successfully authenticated the peer, we save this data for use
    # in future authentications

    Oracle.inquire(peer_oracle, {:register_peer, [{peer_identifier, salt, prime, generator, peer_verifier}]})

    shared_master_key
  end

  # Using the identifier, find the verifier, generator, and prime for a peer we know
  # and then communicate back and forth with them until we've verified them
  @spec inbound_peer(String.t(), reference, pid) :: bitstring
  def inbound_peer(identifier, socket, peer_oracle) do
    {salt, prime, generator, peer_verifier} = Oracle.inquire(peer_oracle, {:load_peer, [identifier]})

    # Necesarry in order to generate the public value & session key
    server =
      Strap.protocol(:srp6a, prime, generator)
      |> Strap.server(peer_verifier)

    # Our public value. The peer will need this in order to generate the derived
    # session key
    public_value =
      server
      |> Strap.public_value()
      |> Base.encode64()

    "HANDSHAKE_CHALLENGE"
    |> Message.build(%{
      salt: salt,
      prime: prime,
      generator: generator,
      public_value: public_value
    })
    |> Message.send(socket)

    %{public_value: peer_public_value} = Message.read(socket)
    {:ok, peer_public_value} = Base.decode64(peer_public_value)
    {:ok, shared_master_key} = Strap.session_key(server, peer_public_value)

    shared_master_key
  end
end
