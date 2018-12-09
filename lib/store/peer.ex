defmodule Elixium.Store.Peer do
  use Elixium.Store

  @moduledoc """
    Store and load data related to peers that a node has communicated with.
    This includes authentication data
  """

  @store_dir "peers"

  def initialize do
    initialize(@store_dir)
  end

  def reorder_peers(ip) do
    transact @store_dir do
      fn ref ->
        {:ok, peers} = Exleveldb.get(ref, "known_peers")
        peers = :erlang.binary_to_term(peers)
        peer = Enum.find(peers, &(elem(&1, 0) == ip))

        Exleveldb.put(ref, "known_peers", :erlang.term_to_binary([peer | peers -- [peer]]))
      end
    end
  end

  @spec save_known_peer({charlist, integer}) :: none
  def save_known_peer(peer) do
    transact @store_dir do
      fn ref ->
        case Exleveldb.get(ref, "known_peers") do
          {:ok, peers} ->
            peers = Enum.uniq([peer | :erlang.binary_to_term(peers)])
            Exleveldb.put(ref, "known_peers", :erlang.term_to_binary(peers))

          :not_found ->
            Exleveldb.put(ref, "known_peers", :erlang.term_to_binary([peer]))
        end
      end
    end
  end

  def load_known_peers do
    transact @store_dir do
      fn ref ->
        case Exleveldb.get(ref, "known_peers") do
          {:ok, peers} -> :erlang.binary_to_term(peers)
          :not_found -> []
        end
      end
    end
  end
end
