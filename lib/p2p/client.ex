defmodule Elixium.P2P.Client do
  require IEx
  alias Elixium.P2P.GhostProtocol.Message
  alias Elixium.P2P.PeerStore

  @moduledoc """
    Provides functions for creating connections to other peers
  """

  @doc """
    Make an outgoing connection to a peer
  """
  @spec connect(charlist, integer) :: none | {:error, String.t()}
  def connect(ip, port) do
    had_previous_connection = had_previous_connection?(ip)

    credentials =
      ip
      |> List.to_string()
      |> load_credentials()

    IO.write("Connecting to node at host: #{ip}, port: #{port}... ")

    case :gen_tcp.connect(ip, port, [:binary, active: false]) do
      {:ok, peer} ->
        IO.puts("Connected")

        key =
          if had_previous_connection do
            authenticate_new_peer(peer, credentials)
          else
            authenticate_peer(peer, credentials)
          end

        <<session_key::binary-size(32)>> <> rest = key

        IO.puts("Authenticated with peer.")

        handle_connection(peer, session_key)

      {:error, reason} ->
        IO.puts("Error connecting to peer: #{reason}")
    end
  end

  @spec handle_connection(reference, <<_::256>>) :: none
  defp handle_connection(peer, session_key) do
    data = IO.gets("What is the data? ")

    message = Message.build("DATA", %{data: data}, session_key)

    :ok = :gen_tcp.send(peer, message)

    handle_connection(peer, session_key)
  end

  # If this node has never communicated with a given peer, it will first
  # need to identify itself.
  @spec authenticate_new_peer(reference, {bitstring, bitstring}) :: bitstring
  defp authenticate_new_peer(peer, {identifier, password}) do
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

    handshake =
      Message.build("HANDSHAKE", %{
        prime: prime,
        generator: generator,
        salt: salt,
        verifier: verifier,
        public_value: public_value,
        identifier: identifier
      })

    :ok = :gen_tcp.send(peer, handshake)

    %{public_value: peer_public_value} = Message.read(peer)

    {:ok, peer_public_value} = Base.decode64(peer_public_value)
    {:ok, shared_master_key} = Strap.session_key(client, peer_public_value)

    shared_master_key
  end

  @spec authenticate_peer(reference, {bitstring, bitstring}) :: bitstring
  defp authenticate_peer(peer, {identifier, password}) do
    encoded_id = Base.encode64(identifier)
    handshake = Message.build("HANDSHAKE", %{identifier: encoded_id})
    :ok = :gen_tcp.send(peer, handshake)

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

    auth = Message.build("HANDSHAKE", %{public_value: public_value})
    :ok = :gen_tcp.send(peer, auth)

    {:ok, shared_master_key} = Strap.session_key(client, peer_public_value)

    shared_master_key
  end

  @spec load_credentials(String.t()) :: {bitstring, bitstring}
  defp load_credentials(ip) do
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

  @spec had_previous_connection?(String.t()) :: boolean
  defp had_previous_connection?(ip) do
    case PeerStore.load_self(ip) do
      :not_found -> false
      {identifier, password} -> true
    end
  end
end
