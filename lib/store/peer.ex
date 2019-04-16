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

  @spec find_potential_peers :: List | :not_found
  def find_potential_peers do
    case load_known_peers() do
      [] -> seed_peers()
      peers -> peers
    end
  end

  @doc """
    Returns a list of seed peers based on config
  """
  @spec seed_peers :: List
  def seed_peers do
    :elixium_core
    |> Application.get_env(:seed_peers)
    |> Enum.map(&peerstring_to_tuple/1)
  end

  # Converts from a colon delimited string to a tuple containing the
  # ip and port. "127.0.0.1:3000" becomes {'127.0.0.1', 3000}
  defp peerstring_to_tuple(peer) do
    [ip, port] = String.split(peer, ":")
    ip = String.to_charlist(ip)

    port =
      case Integer.parse(port) do
        {port, _} -> port
        :error -> nil
      end

    {ip, port}
  end
end
