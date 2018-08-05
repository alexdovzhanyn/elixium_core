defmodule Elixium.P2P.Server do
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

    IO.puts "Accepted connection from client."
    :ok = :gen_tcp.send(socket, "Hello?")

    {:ok, data} = :gen_tcp.recv(socket, 0)
    IO.puts "Recieved data: '#{data}'"
    :ok = :gen_tcp.send(socket, "Hello, #{data}!\r\n")

    server_handler(listen_socket)
  end
end
