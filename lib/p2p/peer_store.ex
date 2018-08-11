defmodule Elixium.P2P.PeerStore do
  use Elixium.Store

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
end
