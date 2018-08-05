defmodule Elixium.P2P.Client do
  def start(ip, port) do
    IO.write "Connecting to node at host: #{ip}, port: #{port}... "
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false])
    IO.puts "Connected"

    handle_connection(socket)
  end

  def handle_connection(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    IO.puts "Recieved data from node: #{data}"

    :ok = :gen_tcp.send(socket, "Mike")
    {:ok, response} = :gen_tcp.recv(socket, 0)

    IO.puts "Node said: #{response}"

    handle_connection(socket)
  end
end
