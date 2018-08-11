defmodule Elixium.P2P.PeerStore do
  use Elixium.Store

  @store_dir ".peers"

  def initialize do
    initialize(@store_dir)
  end

  def register_peer({ip, salt, prime, generator}) do
    transact @store_dir do
      &Exleveldb.put(&1, ip, :erlang.term_to_binary({salt, prime, generator}))
    end
  end

  def load_peer(ip) do
    transact @store_dir do
      fn ref ->
        {:ok, peer} = Exleveldb.get(ref, ip)
        :erlang.binary_to_term(peer)
      end
    end
  end

  def save_self(identifier, password) do
    transact @store_dir do
      &Exleveldb.put(&1, "self", :erlang.term_to_binary({identifier, password}))
    end
  end

  def load_self() do
    transact @store_dir do
      fn ref ->
        case Exleveldb.get(ref, "self") do
          {:ok, self} -> :erlang.binary_to_term(self)
          :not_found -> :not_found
        end
      end
    end
  end
end
