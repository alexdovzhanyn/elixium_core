defmodule Elixium.P2P.Server do
  use GenServer


  # TODO: http://andrealeopardi.com/posts/handling-tcp-connections-in-elixir/
  @initial_state %{socket: nil}

  def start_link do
    GenServer.start_link(__MODULE__, @initial_state)
  end

  def init(state) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 6379, opts)
    {:ok, %{state | socket: socket}}
  end
end
