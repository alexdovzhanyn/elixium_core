defmodule UltraDark.RPC.Client do
  alias JSONRPC2.Clients.TCP

  @moduledoc """
    Example Usage of RPC Client / Server communication
    This assumes two IEX sessions (one for each node)

    ```
    Application.ensure_all_started(:ranch)
    Application.ensure_all_started(:shackle)
    alias UltraDark.RPC.{Client, Peers, Handler}
    ```

    ## Node 1
    ### We start node 1 on Port 9000 and wait for connections
    ```
    JSONRPC2.Servers.TCP.start_listener(Handler, 9000)
    Peers.start_link([])
    ```

    ## Node 2
    ### We start node 2 on Port 8000, and set node 1 as a trusted host.
    ```
    JSONRPC2.Servers.TCP.start_listener(Handler, 8000)
    Client.start("localhost", 8000)
    Peers.start_link([["localhost", 9000]])

    ### On start up, we call Client.connect to let other nodes that our node is up and running
    # Let all peers know that this node is online
    Client.connect("localhost", 8000)
    ```
  """


  @doc """
    Start connection to remote node of `name`
  """
  def start(host, port, name) do
    TCP.start(host, port, name)
  end

  @doc """
    Start connection to your local node
  """
  def start(host, port) do
    TCP.start(host, port, __MODULE__)
  end

  @doc """
    Broadcast the addition of a node to the named node
  """
  def add_node([host, port], to) do
    TCP.notify(to, "add_node", [host, port])
  end

  @doc """
    Send request to Handler to have it broadcast your node to all known nodes
    `host` and `port` must be accessible to the public
    """
  def connect(host, port) do
    TCP.call(__MODULE__, "connect", [host, port])
  end

  @doc """
    Generic function to call a method on a node
    This is mostly used for when broadcasting the same call to multiple nodes

    The reason it's this way is because only the Client doesn't know what nodes are connected
  """
  def call(method, args, name) do
    TCP.call(name, method, args)
  end
end