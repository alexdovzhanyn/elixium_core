defmodule UltraDark.RPC.Handler do
  use JSONRPC2.Server.Handler
  alias UltraDark.RPC.{Client, Peers}

  def start(trusted_nodes) do
    Peers.start_link(nil) # TODO Move to supervisor
    Enum.each(trusted_nodes,
      fn ([host, port]) ->
        Peers.add_node([host, port])
      end)
  end

  @doc """
    Accept incoming connection from a node.
    Adds it to Peers.nodes for future broadcasting
  """
  def handle_request("add_node", [host, port]) do
    node_name = Peers.add_node([host, port])
    IO.puts "Connected to #{node_name}"
  end

  @doc """
    Broadcasts your node to other nodes
  """  
  def handle_request("connect", connecting_node) do
    Enum.each(Peers.nodes, fn peer_node -> 
      Client.add_node(connecting_node, peer_node)
    end)
  end
end