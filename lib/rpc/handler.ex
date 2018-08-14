defmodule UltraDark.RPC.Handler do
  use JSONRPC2.Server.Handler
  alias UltraDark.RPC.{Client, Peers}

  @doc """
    Accept incoming connection from a node.
    Adds it to Peers.nodes for future broadcasting
  """
  def handle_request("add_node", [host, port]) do
    node_name = Peers.add_node({host, port})
    IO.puts "Connected to #{node_name}"
  end

  @doc """
    Broadcasts your node to other nodes
  """  
  def handle_request("connect", [con_host, con_port]) do
    Enum.each(Peers.nodes, fn peer_node -> 
      Client.add_node({con_host, con_port}, peer_node)
    end)
  end
end