defmodule Elixium.P2P.Server do
  require IEx
  alias Elixium.P2P.GhostProtocol.Parser
  @port 4001

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
    {:ok, data} = :gen_tcp.recv(socket, 0)

    register_new_peer(data, socket)

    server_handler(listen_socket)
  end

  # Handle incoming authentication messages from peers, and save to their
  # identity to the database for later
  defp register_new_peer(request, socket) do
    Parser.parse(request)
    [prime, generator, salt, client_verifier, client_public_value] = String.split(request, "|")
    {generator, _} = Integer.parse(generator)
    {:ok, client_verifier} = Base.decode64(client_verifier)
    {:ok, client_public_value} = Base.decode64(client_public_value)

    server =
      Strap.protocol(:srp6a, prime, generator)
      |> Strap.server(client_verifier)

    server_public_value =
      Strap.public_value(server)
      |> Base.encode64()

    response =
      [prime, Integer.to_string(generator), salt, server_public_value]
      |> Enum.reduce(fn x, acc -> acc <> "|" <> x end)

    :ok = :gen_tcp.send(socket, response)

    {:ok, private_server_session_key} =
      Strap.session_key(server, client_public_value)

    IO.puts Base.encode64(private_server_session_key)
  end
end
