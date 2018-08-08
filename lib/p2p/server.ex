defmodule Elixium.P2P.Server do
  require IEx
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

    verifier = "AnotherPass"
    salt = "mysalt"
    {prime, generator} = Strap.prime_group(2048)

    server =
      Strap.protocol(:srp6a, prime, generator)
      |> Strap.server(verifier)

    server_public_value = Strap.public_value(server)

    IO.puts "Prime: #{Base.encode64(prime)}"
    IO.puts "Generator: #{Integer.to_string(generator)}"
    IO.puts "Salt: #{salt}"
    IO.puts "Server Pub: #{Base.encode64(server_public_value)}"

    response =
      [Base.encode64(prime), Integer.to_string(generator), salt, Base.encode64(server_public_value)]
      |> Enum.reduce(fn x, acc -> acc <> "|" <> x end)

    # IO.puts "Accepted connection from client."
    :ok = :gen_tcp.send(socket, response)

    {:ok, data} = :gen_tcp.recv(socket, 0)
    # IO.puts "Recieved data: '#{data}'"

    IO.puts "Client Pub: #{data}"

    {:ok, client_public_value} = Base.decode64(data)

    {:ok, private_server_session_key} =
      Strap.session_key(server, client_public_value)

    IO.puts "PRIVATE SESSION KEY = #{Base.encode64(private_server_session_key)}"

    # :ok = :gen_tcp.send(socket, "Hello, #{data}!\r\n")

    server_handler(listen_socket)
  end
end
