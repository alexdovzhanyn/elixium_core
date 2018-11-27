defmodule Elixium.HostCheck do
  alias Elixium.Store.Oracle
  use GenServer
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    Process.send_after(self(), :check_health, 1000)
    {:ok, %{}}
  end

  def handle_info(:check_health, state) do
    case Oracle.inquire(:"Elixir.Elixium.Store.PeerOracle", {:load_known_peers, []}) do
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
    case :inet.peername(socket) do
      {:ok, {add, _port}} ->
        ip = :inet_parse.ntoa(add)
        Oracle.inquire(:"Elixir.Elixium.Store.PeerOracle", {:reorder_peers, [ip]})
      {:error, :einval} -> :err
    end

    {:noreply, state}
  end

  def handle_info({:tcp, _, _}, state), do: {:noreply, state}

end
