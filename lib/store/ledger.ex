defmodule Elixium.Store.Ledger do
  alias Elixium.Block
  use Elixium.Store

  @moduledoc """
    Provides an interface for interacting with the blockchain stored within LevelDB. This
    is where blocks are stored and fetched
  """

  @store_dir ".chaindata"
  @ets_name :chaindata

  def initialize do
    initialize(@store_dir)
    :ets.new(@ets_name, [:ordered_set, :public, :named_table])
  end

  @doc """
    Add a block to leveldb, indexing it by its hash (this is the most likely piece of data to be unique)
  """
  def append_block(block) do
    transact @store_dir do
      &Exleveldb.put(&1, String.to_atom(block.hash), :erlang.term_to_binary(block))
    end

    :ets.insert(@ets_name, {block.index, block.hash, block})
  end

  @spec drop_block(Block) :: none
  def drop_block(block) do
    transact @store_dir do
      &Exleveldb.delete(&1, String.to_atom(block.hash))
    end

    :ets.delete(@ets_name, block.index)
  end

  @doc """
    Given a block hash, return its contents
  """
  @spec retrieve_block(String.t()) :: Block
  def retrieve_block(hash) do
    # Only check the store if we don't have this hash in our ETS cache
    case :ets.match(@ets_name, {'_', hash, '$1'}) do
      [] -> do_retrieve_block_from_store(hash)
      [block] -> block
    end
  end

  defp do_retrieve_block_from_store(hash) do
    transact @store_dir do
      fn ref ->
        case Exleveldb.get(ref, hash) do
          {:ok, block} -> :erlang.binary_to_term(block)
          err -> err
        end
      end
    end
  end

  @doc """
    Return the whole chain from leveldb
  """
  def retrieve_chain do
    chain =
      transact @store_dir do
        fn ref ->
          ref
          |> Exleveldb.map(fn {_, block} -> :erlang.binary_to_term(block) end)
          |> Enum.sort_by(& &1.index, &>=/2)
        end
      end

    chain
  end

  @doc """
    Hydrate ETS with our chain data
  """
  def hydrate do
    ets_hydrate = Enum.map(retrieve_chain(), &({&1.index, String.to_atom(&1.hash), &1}))
    :ets.insert(@ets_name, ets_hydrate)
  end

  @doc """
    Returns the most recent block on the chain
  """
  @spec last_block :: Block
  def last_block do
    case :ets.last(@ets_name) do
      [] ->
        transact @store_dir do
          fn ref ->
            :err
            # TODO
            # {:ok, block} = Exleveldb.get()
          end
        end
      key ->
        [{_index, _key, block}] = :ets.lookup(@ets_name, key)
        block
    end
  end

  @doc """
    Returns the block at a given index
  """
  @spec block_at_height(integer) :: Block
  def block_at_height(height) do
    case :ets.lookup(@ets_name, height) do
      [] -> :none
      [{_index, _key, block}] -> block
    end
  end

  @doc """
    Returns the number of blocks in the chain
  """
  @spec count_blocks :: integer
  def count_blocks, do: :ets.info(@ets_name, :size)

  def empty? do
    empty?(@store_dir)
  end
end
