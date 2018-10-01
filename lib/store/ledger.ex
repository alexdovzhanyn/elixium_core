defmodule Elixium.Store.Ledger do
  alias Elixium.Blockchain.Block
  use Elixium.Store

  @moduledoc """
    Provides an interface for interacting with the blockchain stored within LevelDB. This
    is where blocks are stored and fetched
  """

  @store_dir ".chaindata"
  @ets_name :chaindata
  @block_cache :block_cache

  def initialize do
    initialize(@store_dir)
    :ets.new(@ets_name, [:ordered_set, :public, :named_table])
    :ets.new(@block_cache, [:named_table])
  end

  @doc """
    Store & Delete Blocks from the block cache ets table
  """
  def store(block) do
    validate_operation(:ets.insert(@block_cache, {block}))
  end

  def delete(block) do
    validate_operation(:ets.delete(@block_cache, {block}))
  end
  @doc """
    Here we're just checking if the block given i.e the previoius block (the one being behind) is actually behind with the correct index
  """
  def check_block(block_2, block_1) do
    with [block_forward] <- :ets.lookup(@block_cache, block_2) do
      with {:up, block_2} <- check_index(block_2, block_1) do
        {:up, block_2, block_1}
      end
    end
  end
  @doc """
    We know were looking for a matching partner in the table so -1 in this case
  """
  defp check_index(block_2, block_1) do
    correct_index = block_2.index - 1
    if block_1.index == correct_index do
      {:up, block_2}
    else
      {:error, "Block Out of Sync"}
    end
  end
  @doc """
    Now that the blocks have been verified and processed lets remove them from the table
  """
  def remove_blocks({type, message, block_2, block_1}) do
    with :ok <- delete(block_2),
          :ok <- delete(block_1)do
    :ok
    end
  end
  @doc """
    this is where we can patch into the validator functions, then return the result
  """
  def check_validation_of_blocks({:up, block_forward, block_back}), do: {:ok, "Validated Forwards", block_forward, block_back}
  def check_validation_of_blocks({:down, block_forward, block_back}), do: {:ok, "Validated Backwards", block_forward, block_back}
  @doc """
    Simple Helper Function to verify critical operations
  """
  defp validate_operation(ops) do
   case ops do
     true ->
       :ok
     false ->
       :error
     end
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

  @doc """
    Given a block hash, return its contents
  """
  @spec retrieve_block(String.t()) :: Block
  def retrieve_block(hash) do
    # Only check the store if we don't have this hash in our ETS cache
    case :ets.match(@ets_name, {'_', hash, '$1'}) do
      [] ->
        transact @store_dir do
          fn ref ->
            case Exleveldb.get(ref, hash) do
              {:ok, block} -> :erlang.binary_to_term(block)
              err -> err
            end
          end
        end
      [block] -> block
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


    ets_hydrate = Enum.map(chain, &({&1.index, String.to_atom(&1.hash), &1}))
    :ets.insert(@ets_name, ets_hydrate)

    chain
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
