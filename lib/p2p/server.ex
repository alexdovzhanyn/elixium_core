defmodule Elixium.P2P.Server do
  require IEx
  alias Elixium.P2P.GhostProtocol.Parser
  alias Elixium.P2P.GhostProtocol.Message
  @port 31013

  # Start a server and pass the socket to a listener function
  def start do
    IO.puts "Starting server on port #{@port}."
    {:ok, listen_socket} = :gen_tcp.listen(@port, [:binary, reuseaddr: true, active: false])

    # TODO: Replace with ranch lib
    for _ <- 0..10, do: spawn(fn -> server_handler(listen_socket) end)

    Process.sleep(:infinity)
  end

  def server_handler(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)

    {:ok, {addr, port}} = :inet.peername(socket)

    peername =
      addr
      |> :inet_parse.ntoa()
      |> to_string()

    IO.puts "Accepted message from #{peername}"

    data =
      socket
      |> :gen_tcp.recv(0)
      |> Parser.parse

    register_new_peer(data, socket)

    server_handler(listen_socket)
  end

  # Handle incoming authentication messages from peers, and save to their
  # identity to the database for later
  defp register_new_peer(message, socket) do
    %{
      public_value: peer_public_value,
      generator: generator,
      prime: prime,
      verifier: peer_verifier,
      salt: salt
    } = message

    {:ok, peer_verifier} = Base.decode64(peer_verifier)
    {:ok, peer_public_value} = Base.decode64(peer_public_value)

    server =
      Strap.protocol(:srp6a, prime, generator)
      |> Strap.server(peer_verifier)

    server_public_value =
      Strap.public_value(server)
      |> Base.encode64()

    response = Message.build("HANDSHAKE_AUTH", %{
      public_value: server_public_value
    })

    :ok = :gen_tcp.send(socket, response)

    {:ok, shared_master_key} =
      Strap.session_key(server, peer_public_value)

    IO.puts "Authenticated with peer."
  end
end
