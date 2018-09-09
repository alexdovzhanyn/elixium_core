defmodule Elixium.Store.Ledger do
  alias Elixium.Blockchain.Block
  use Elixium.Store

  @moduledoc """
    Provides an interface for interacting with the blockchain stored within LevelDB. This
    is where blocks are stored and fetched
  """

  @store_dir ".chaindata"
  @ets_name :chaindata

  def initialize do
    initialize(@store_dir)
    :ets.new(@ets_name, [:set, :public, :named_table])
  end

  @doc """
    Add a block to leveldb, indexing it by its hash (this is the most likely piece of data to be unique)
  """
  def append_block(block) do
    hash = String.to_atom(block.hash)

    transact @store_dir do
      &Exleveldb.put(&1, hash, :erlang.term_to_binary(block))
    end

    :ets.insert(@ets_name, {hash, block})
  end

  @doc """
    Given a block hash, return its contents
  """
  @spec retrieve_block(String.t()) :: Block
  def retrieve_block(hash) do
    hash = String.to_atom(hash)
    # Only check the store if we don't have this hash in our ETS cache
    case :ets.lookup(@ets_name, hash) do
      [] ->
        transact @store_dir do
          fn ref ->
            {:ok, block} = Exleveldb.get(ref, hash)
            :erlang.binary_to_term(block)
          end
        end
      [_key, block] -> block
    end
  end

  @doc """
    Return the whole chain from leveldb
  """
  def retrieve_chain do
    transact @store_dir do
      fn ref ->
        ref
        |> Exleveldb.map(fn {_, block} -> :erlang.binary_to_term(block) end)
        |> Enum.sort_by(& &1.index, &>=/2)
      end
    end
  end

  def empty? do
    empty?(@store_dir)
  end
end
