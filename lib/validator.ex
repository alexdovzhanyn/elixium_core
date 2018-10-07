defmodule Elixium.Validator do
  alias Elixium.Blockchain.Block
  alias Elixium.Utilities
  alias Elixium.KeyPair
  alias Elixium.Store.Ledger
  alias Elixium.Store.Utxo
  alias Decimal, as: D

  @moduledoc """
    Responsible for implementing the consensus rules to all blocks and transactions
  """

  @doc """
    A block is considered valid if the index is greater than the index of the previous block,
    the previous_hash is equal to the hash of the previous block, and the hash of the block,
    when recalculated, is the same as what the listed block hash is
  """
  @spec is_block_valid?(Block, number) :: :ok | {:error, any}
  def is_block_valid?(block, difficulty, last_block \\ Ledger.last_block(), pool_check \\ &Utxo.in_pool?/1) do
    with :ok <- valid_index(block.index, last_block.index),
         :ok <- valid_prev_hash?(block.previous_hash, last_block.hash),
         :ok <- valid_hash?(block, difficulty),
         :ok <- valid_coinbase?(block),
         :ok <- valid_transactions?(block, pool_check) do
      :ok
    else
      err -> err
    end
  end

  @spec valid_index(number, number) :: :ok | {:error, {:invalid_index, number, number}}
  defp valid_index(index, prev_index) when index > prev_index, do: :ok

  defp valid_index(index, prev_index) when index <= prev_index,
    do: {:error, {:invalid_index, prev_index, index}}

  @spec valid_prev_hash?(String.t(), String.t()) ::
          :ok | {:error, {:wrong_hash, {:doesnt_match_last, String.t(), String.t()}}}
  defp valid_prev_hash?(prev_hash, last_block_hash) when prev_hash == last_block_hash, do: :ok

  defp valid_prev_hash?(prev_hash, last_block_hash) when prev_hash != last_block_hash,
    do: {:error, {:wrong_hash, {:doesnt_match_last, prev_hash, last_block_hash}}}

  @spec valid_hash?(Block, number) :: :ok | {:error, {:wrong_hash, {:too_high, String.t(), number}}}
  defp valid_hash?(%{
         index: index,
         previous_hash: previous_hash,
         timestamp: timestamp,
         nonce: nonce,
         hash: hash,
         merkle_root: merkle_root
       }, difficulty) do
    with :ok <- compare_hash({index, previous_hash, timestamp, nonce, merkle_root}, hash),
         :ok <- (fn -> if Block.hash_beat_target?(%{hash: hash, difficulty: difficulty}), do: :ok, else: {:error, {:wrong_hash, {:too_high, hash, difficulty}}} end).()
         do
      :ok
    else
      err -> err
    end
  end

  @spec compare_hash({number, String.t(), String.t(), number, String.t()}, String.t()) ::
          :ok | {:error, {:wrong_hash, {:doesnt_match_provided, String.t(), String.t()}}}
  defp compare_hash({index, previous_hash, timestamp, nonce, merkle_root}, hash) do
    computed =
      [Integer.to_string(index), previous_hash, timestamp, Integer.to_string(nonce), merkle_root]
      |> Utilities.sha3_base16()

    if computed == hash do
      :ok
    else
      {:error, {:wrong_hash, {:doesnt_match_provided, computed, hash}}}
    end
  end

  @spec valid_coinbase?(Block) :: :ok | {:error, :no_coinbase}
  def valid_coinbase?(%{transactions: transactions, index: block_index}) do
    coinbase = hd(transactions)

    with :ok <- (&if(&1 != nil, do: :ok, else: {:error, :no_coinbase})).(coinbase),
         :ok <- is_coinbase?(coinbase),
         :ok <- appropriate_coinbase_output?(transactions, block_index) do
      :ok
    else
      err -> err
    end
  end

  @doc """
    Checks if a transaction is valid. A transaction is considered valid if
    1) all of its inputs are currently in our UTXO pool and 2) all of its inputs
    have a valid signature, signed by the owner of the private key associated to
    the input (the addr). pool_check is a function which tests whether or not a
    given input is in a pool (this is mostly used in the case of a fork), and
    this function must return a boolean.
  """
  @spec valid_transaction?(Transaction, function) :: boolean
  def valid_transaction?(%{inputs: inputs}, pool_check \\ &Utxo.in_pool?/1) do
    inputs
    |> Enum.map(fn input ->
      # Ensure that this input is in our UTXO pool
      if pool_check.(input) do
        # Check if this UTXO has a valid signature
        case {Base.decode16(input.addr), Base.decode16(input.signature)} do
          {{:ok, pub}, {:ok, sig}} -> KeyPair.verify_signature(pub, sig, input.txoid)
          _ -> false
        end
      else
        false
      end
    end)
    |> Enum.all?(& &1)
  end

  @spec valid_transactions?(Block, function) :: :ok | {:error, :invalid_inputs}
  def valid_transactions?(%{transactions: transactions}, pool_check \\ &Utxo.in_pool?/1) do
    if Enum.all?(transactions, &valid_transaction?(&1, pool_check)), do: :ok, else: {:error, :invalid_inputs}
  end

  @spec is_coinbase?(Transaction) :: :ok | {:error, {:not_coinbase, String.t()}}
  defp is_coinbase?(tx) do
    if tx.txtype == "COINBASE", do: :ok, else: {:error, {:not_coinbase, tx.txtype}}
  end

  @spec appropriate_coinbase_output?(list, number) :: :ok | {:error, :invalid_coinbase}
  defp appropriate_coinbase_output?([coinbase | transactions], block_index) do
    total_fees = Block.total_block_fees(transactions)
    reward = Block.calculate_block_reward(block_index)
    amount = hd(coinbase.outputs).amount

    if D.equal?(D.add(total_fees, reward), amount) do
      :ok
    else
      {:error, {:invalid_coinbase, total_fees, reward, amount}}
    end
  end
end
