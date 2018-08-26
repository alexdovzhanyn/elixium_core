defmodule Elixium.Store.Utxo do
  use Elixium.Store

  @moduledoc """
    Provides an interface for interacting with the UTXOs stored in level db
  """

  @store_dir ".utxo"

  def initialize do
    initialize(@store_dir)
  end

  @doc """
    Add a utxo to leveldb, indexing it by its txoid
  """
  @spec add_utxo(map) :: :ok | {:error, any}
  def add_utxo(utxo) do
    transact @store_dir do
      &Exleveldb.put(&1, String.to_atom(utxo.txoid), :erlang.term_to_binary(utxo))
    end
  end

  @spec remove_utxo(String.t()) :: :ok | {:error, any}
  def remove_utxo(txoid) do
    transact @store_dir do
      &Exleveldb.delete(&1, String.to_atom(txoid))
    end
  end

  @doc """
    Retrieve a UTXO by its txoid
  """
  @spec retrieve_utxo(String.t()) :: map
  def retrieve_utxo(txoid) do
    transact @store_dir do
      fn ref ->
        {:ok, utxo} = Exleveldb.get(ref, String.to_atom(txoid))
        :erlang.binary_to_term(utxo)
      end
    end
  end

  @spec retrieve_all_utxos :: list
  def retrieve_all_utxos do
    transact @store_dir do
      &Exleveldb.map(&1, fn {_, utxo} -> :erlang.binary_to_term(utxo) end)
    end
  end

  @spec update_with_transactions(list) :: :ok | {:error, any}
  def update_with_transactions(transactions) do
    transact @store_dir do
      fn ref ->
        remove =
          transactions
          |> Enum.flat_map(& &1.inputs)
          |> Enum.map(&{:delete, &1.txoid})

        add =
          transactions
          |> Enum.flat_map(& &1.outputs)
          |> Enum.map(&{:put, &1.txoid, :erlang.term_to_binary(&1)})

        Exleveldb.write(ref, Enum.concat(remove, add))
      end
    end
  end

  @spec find_by_address(String.t()) :: list
  def find_by_address(public_key) do
    transact @store_dir do
      fn ref ->
        ref
        |> Exleveldb.map(fn {_, utxo} -> :erlang.binary_to_term(utxo) end)
        |> Enum.filter(&(&1.addr == public_key))
      end
    end
  end
end
