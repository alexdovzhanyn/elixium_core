defmodule Elixium.P2P.Client do
  require IEx
  def start(ip, port) do
    IO.write "Connecting to node at host: #{ip}, port: #{port}... "
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false])
    IO.puts "Connected"

    handle_connection(socket)
  end

  def handle_connection(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    # IO.puts "Recieved data from node: #{data}"

    [prime, generator, salt, server_public_value] = String.split(data, "|")

    IO.puts "Prime: #{prime}"
    IO.puts "Generator: #{generator}"
    IO.puts "Salt: #{salt}"
    IO.puts "Server Pub: #{server_public_value}"

    {:ok, prime} = Base.decode64(prime)
    {:ok, server_public_value} = Base.decode64(server_public_value)
    {generator, _} = Integer.parse(generator)

    client =
      Strap.protocol(:srp6a, prime, generator)
      |> Strap.client("Alex", "somepassword", salt)

    client_public_value = Strap.public_value(client)

    IO.puts "Client Pub: #{Base.encode64(client_public_value)}"

    {:ok, private_client_session_key} = Strap.session_key(client, server_public_value)

    IO.puts "private_client_session_key = #{Base.encode64(private_client_session_key)}"

    :ok = :gen_tcp.send(socket, Base.encode64(client_public_value))
    {:ok, response} = :gen_tcp.recv(socket, 0)

    # IO.puts "Node said: #{response}"

    handle_connection(socket)
  end
end
