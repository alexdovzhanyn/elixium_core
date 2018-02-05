defmodule UltraDark.Ledger do
  alias UltraDark.Blockchain.Block
  require Exleveldb

  def initialize do
    {:ok, ref} = Exleveldb.open(".chaindata") # Generate a new leveldb instance if none exists
    Exleveldb.close(ref) # Immediately close after ensuring creation, we don't need it constantly open
  end

  @doc """
    Add a block to leveldb, indexing it by its hash (this is the most likely piece of data to be unique)
  """
  def append_block(block) do
    within_db_transaction fn ref ->
      Exleveldb.put(ref, String.to_atom(block.hash), :erlang.term_to_binary(block))
    end
  end

  @doc """
    Given a block hash, return its contents
  """
  @spec retrieve_block(String.t) :: %Block{}
  def retrieve_block(hash) do
    within_db_transaction fn ref ->
      {:ok, block} = Exleveldb.get(ref, String.to_atom(hash))
      :erlang.binary_to_term(block)
    end
  end

  @doc """
    Return the whole chain from leveldb
  """
  def retrieve_chain do
    within_db_transaction fn ref ->
      Exleveldb.map(ref, fn {_, block} -> :erlang.binary_to_term(block) end)
      |> Enum.sort_by(&(&1.index),&>=/2)
    end
  end

  def is_empty? do
    within_db_transaction fn ref -> Exleveldb.is_empty? ref end
  end

  @doc """
    We don't want to have to remember to open and keep a reference to the leveldb instance
    each time we interact with the chain. Let's make a wrapper function that does this for us
  """
  defp within_db_transaction(function) do
    {:ok, ref} = Exleveldb.open(".chaindata")
    result = function.(ref)
    Exleveldb.close(ref)
    result
  end
end
