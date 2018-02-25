defmodule UltraDark.Ledger do
  alias UltraDark.Blockchain.Block
  alias UltraDark.Store
  require Exleveldb

  @store_dir ".chaindata"

  def initialize do
    Store.initialize(@store_dir)
  end

  @doc """
    Add a block to leveldb, indexing it by its hash (this is the most likely piece of data to be unique)
  """
  def append_block(block) do
    fn ref -> Exleveldb.put(ref, String.to_atom(block.hash), :erlang.term_to_binary(block)) end
    |> Store.transact(@store_dir)
  end

  @doc """
    Given a block hash, return its contents
  """
  @spec retrieve_block(String.t()) :: Block
  def retrieve_block(hash) do
    fn ref ->
      {:ok, block} = Exleveldb.get(ref, String.to_atom(hash))
      :erlang.binary_to_term(block)
    end
    |> Store.transact(@store_dir)
  end

  @doc """
    Return the whole chain from leveldb
  """
  def retrieve_chain do
    fn ref ->
      ref
      |> Exleveldb.map(fn {_, block} -> :erlang.binary_to_term(block) end)
      |> Enum.sort_by(& &1.index, &>=/2)
    end
    |> Store.transact(@store_dir)
  end

  def empty? do
    Store.is_empty?(@store_dir)
  end
end
