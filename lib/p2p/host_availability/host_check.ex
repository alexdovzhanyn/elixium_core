defmodule Elixium.HostCheck do
  use GenServer
  require IEx
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    Process.send_after(self(), :check_health, 1000)
    {:ok, %{}}
  end

  def handle_info(:check_health, state) do

    case GenServer.call(:"Elixir.Elixium.Store.PeerOracle", {:load_known_peers, []}) do
      :not_found -> :ok
      peers -> Enum.each(peers, &attempt_response/1)
    end

    Process.send_after(self(), :check_health, 600000)
    {:noreply, state}
  end

  defp attempt_response({ip, _port}) do
    with {:ok, socket} <- :gen_tcp.connect(ip, 31014, [:binary, active: true], 1000) do
      :gen_tcp.send(socket, <<0>>)
    end
  end

  def handle_info({:tcp_closed, _}, state) do
    {:noreply, state}
  end

  def handle_info({:tcp, socket, <<1>>}, state) do
    #Shuffle List
    {:ok, {add, _port}} = :inet.peername(socket)
    ip =
      add
      |> :inet_parse.ntoa()

    GenServer.call(:"Elixir.Elixium.Store.PeerOracle", {:reorder_peers, [ip]})
    {:noreply, state}
  end

  def handle_info({:tcp, _, _} state), do: {:noreply, state} 

end
