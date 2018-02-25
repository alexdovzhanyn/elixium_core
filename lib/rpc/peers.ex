defmodule UltraDark.RPC.Peers do
  use Agent
  alias UltraDark.RPC.{Client}

  def start_link(trusted_nodes) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
    Enum.each(trusted_nodes,
      fn ([host, port]) ->
        add_node([host, port])
      end)
  end

  def add_node([host, port]) do
    name = node_name([host, port])
  
    unless node_exists?(name) do
      Client.start(host, port, name)
      Agent.update(__MODULE__, fn state -> [name | state] end)
    end
    
    name
  end

  def nodes do
    Agent.get(__MODULE__, fn state -> state end)
  end

  defp node_name([host, port]) do
    :"#{host}:#{port}"
  end

  defp node_exists?(name) do
    Enum.member?(nodes(), name)
  end
end