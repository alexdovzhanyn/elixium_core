defmodule Elixium.Store.Peer do
  use Elixium.Store

  @moduledoc """
    Store and load data related to peers that a node has communicated with.
    This includes authentication data
  """

  @store_dir ".peers"

  def initialize do
    initialize(@store_dir)
  end

  def register_peer({identifier, salt, prime, generator, verifier}) do
    transact @store_dir do
      &Exleveldb.put(&1, identifier, :erlang.term_to_binary({salt, prime, generator, verifier}))
    end
  end

  def load_peer(identifier) do
    transact @store_dir do
      fn ref ->
        case Exleveldb.get(ref, identifier) do
          {:ok, peer} -> :erlang.binary_to_term(peer)
          :not_found -> :not_found
        end
      end
    end
  end

  #Removes peer if no response was heard
  def remove_peer(identifier) do
    transact @store_dir do
      &Exleveldb.delete(&1, identifier)
    end
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

  def save_self(identifier, password, ip) do
    transact @store_dir do
      &Exleveldb.put(&1, "self_#{ip}", :erlang.term_to_binary({identifier, password}))
    end
  end

  def load_self(ip) do
    transact @store_dir do
      fn ref ->
        case Exleveldb.get(ref, "self_#{ip}") do
          {:ok, self} -> :erlang.binary_to_term(self)
          :not_found -> :not_found
        end
      end
    end
  end

  @spec save_known_peer({charlist, integer}) :: none
  def save_known_peer(peer) do
    transact @store_dir do
      fn ref ->
        case Exleveldb.get(ref, "known_peers") do
          {:ok, peers} ->
            peers =
              [peer | :erlang.binary_to_term(peers)]
              #add here

            Exleveldb.put(ref, "known_peers", :erlang.term_to_binary(peers))

          :not_found ->
            #add here
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
          :not_found -> :not_found
        end
      end
    end
  end
end
