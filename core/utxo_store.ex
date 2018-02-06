defmodule UltraDark.UtxoStore do
  alias UltraDark.Store
  require Exleveldb

  @store_dir ".utxo"

  def initialize do
    Store.initialize(@store_dir)
  end

  @doc """
    Add a utxo to leveldb, indexing it by its txoid
  """
  def add_utxo(utxo) do
    fn ref -> Exleveldb.put(ref, String.to_atom(utxo.txoid), :erlang.term_to_binary(utxo)) end
    |> Store.transact(@store_dir)
  end

  def remove_utxo(txoid) do
    fn ref -> Exleveldb.delete(ref, String.to_atom(txoid)) end
    |> Store.transact(@store_dir)
  end

  @doc """
    Retrieve a UTXO by its txoid
  """
  @spec retrieve_utxo(String.t) :: map
  def retrieve_utxo(txoid) do
    fn ref ->
      {:ok, utxo} = Exleveldb.get(ref, String.to_atom(txoid))
      :erlang.binary_to_term(utxo)
    end
    |> Store.transact(@store_dir)
  end

  @spec retrieve_all_utxos :: list
  def retrieve_all_utxos do
    fn ref ->
      Exleveldb.map(ref, fn {_, utxo} -> :erlang.binary_to_term(utxo) end)
    end
    |> Store.transact(@store_dir)
  end

  @spec update_with_transactions(list) :: :ok | {:error, any}
  def update_with_transactions(transactions) do
    fn ref ->
      remove =
      transactions
      |> Enum.flat_map(&(&1.inputs))
      |> Enum.map(&({:delete, &1.txoid}))

      add =
      transactions
      |> Enum.flat_map(&(&1.outputs))
      |> Enum.map(&({:put, &1.txoid, :erlang.term_to_binary(&1)}))

      Exleveldb.write(ref, Enum.concat(remove, add))
    end
    |> Store.transact(@store_dir)
  end

  @spec find_by_address(String.t) :: list
  def find_by_address(public_key) do
    fn ref ->
      Exleveldb.map(ref, fn {_, utxo} -> :erlang.binary_to_term(utxo) end)
      |> Enum.filter(&(&1.addr == public_key))
    end
    |> Store.transact(@store_dir)
  end
end
