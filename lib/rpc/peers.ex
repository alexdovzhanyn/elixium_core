defmodule UltraDark.RPC.Peers do
  use Agent
  alias UltraDark.RPC.{Client}

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def add_node([host, port]) do
    name = node_name([host, port])
    Client.start(host, port, name)
    Agent.update(__MODULE__, fn state -> [name | state] end)

    name
  end

  def nodes do
    Agent.get(__MODULE__, fn state -> state end)
  end

  defp node_name([host, port]) do
    :"#{host}:#{port}"
  end
end