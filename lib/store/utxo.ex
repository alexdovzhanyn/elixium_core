defmodule Elixium.Store.Utxo do
  use Elixium.Store
  require IEx

  @moduledoc """
    Provides an interface for interacting with the UTXOs stored in level db
  """

  @store_dir ".utxo"
  @ets_name :utxo

  @type utxo() :: %{
    txoid: String.t(),
    addr: String.t(),
    amount: number,
    signature: String.t() | none()
  }

  def initialize do
    initialize(@store_dir)
    :ets.new(@ets_name, [:ordered_set, :public, :named_table])
  end

  @doc """
    Add a utxo to leveldb, indexing it by its txoid
  """
  @spec add_utxo(utxo()) :: :ok | {:error, any}
  def add_utxo(utxo) do
    transact @store_dir do
      &Exleveldb.put(&1, String.to_atom(utxo.txoid), :erlang.term_to_binary(utxo))
    end

    :ets.insert(@ets_name, {utxo.txoid, utxo.addr, utxo})
  end

  @spec remove_utxo(String.t()) :: :ok | {:error, any}
  def remove_utxo(txoid) do
    transact @store_dir do
      &Exleveldb.delete(&1, String.to_atom(txoid))
    end

    :ets.delete(@ets_name, txoid)
  end

  @doc """
    Retrieve a UTXO by its txoid
  """
  @spec retrieve_utxo(String.t()) :: map
  def retrieve_utxo(txoid) do
    case :ets.lookup(@ets_name, txoid) do
      [] ->
        transact @store_dir do
          fn ref ->
            {:ok, utxo} = Exleveldb.get(ref, String.to_atom(txoid))
            :erlang.binary_to_term(utxo)
          end
        end
      [{_txoid, _addr, utxo}] -> utxo
    end
  end

  @doc """
    Check if a UTXO is currently in the pool
  """
  @spec in_pool?(utxo()) :: true | false
  def in_pool?(%{txoid: txoid}), do: retrieve_utxo(txoid) != []

  @spec retrieve_all_utxos :: list(utxo())
  def retrieve_all_utxos do
    # It might be better to get from ets here, but there might be the issue
    # that ets wont have an UTXO that the store does, causing a block to be
    # invalidated somewhere down the line even if the inputs are all valid.
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

        transactions
        |> Enum.flat_map(& &1.inputs)
        |> Enum.each(&(:ets.delete(@ets_name, &1.txoid)))

        transactions
        |> Enum.flat_map(& &1.outputs)
        |> Enum.each(&(:ets.insert(@ets_name, {&1.txoid, &1.addr, &1})))
      end
    end
  end


  @doc """
    Fetches all keys from the wallet and passes them through to return the signed utxo's for later use
  """
  @spec retrieve_wallet_utxos :: list(utxo())
  def retrieve_wallet_utxos do
    path = Path.expand("../../.keys")
    case File.ls(path) do
      {:ok, keyfiles} ->
        Enum.flat_map(keyfiles, fn file ->
          {pub, priv} = Elixium.KeyPair.get_from_file(path <> "/#{file}")

          pub
          |> Elixium.KeyPair.address_from_pubkey
          |> find_by_address()
          |> Enum.map( &(Map.merge(&1, %{signature: Elixium.KeyPair.sign(priv, &1.txoid) |> Base.encode16})) )
        end)
      {:error, :enoent} -> IO.puts "No keypair file found"
    end
end

  @doc """
    Return a list of UTXOs that a given address (public key) can use as inputs
  """
  @spec find_by_address(String.t()) :: list(utxo())
  def find_by_address(public_key) do
    case :ets.match(@ets_name, {'_', public_key, '$1'}) do
      [] -> do_find_by_address_from_store(public_key)
      utxos -> utxos
    end
  end

  defp do_find_by_address_from_store(public_key) do
    transact @store_dir do
      fn ref ->
        ref
        |> Exleveldb.map(fn {_, utxo} -> :erlang.binary_to_term(utxo) end)
        |> Enum.filter(&(&1.addr == public_key))
      end
    end
  end
end
