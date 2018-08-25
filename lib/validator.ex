defmodule Elixium.Validator do
  alias Elixium.Blockchain.Block
  alias Elixium.Utilities
  alias Elixium.KeyPair
  alias Decimal, as: D

  @moduledoc """
    Responsible for implementing the consensus rules to all blocks and transactions
  """

  @doc """
    A block is considered valid if the index is greater than the index of the previous block,
    the previous_hash is equal to the hash of the previous block, and the hash of the block,
    when recalculated, is the same as what the listed block hash is
  """
  @spec is_block_valid?(Block, list, number) :: :ok | {:error, any}
  def is_block_valid?(block, chain, difficulty) do
    last_block = List.first(chain)

    with :ok <- valid_index(block.index, last_block.index),
         :ok <- valid_prev_hash?(block.previous_hash, last_block.hash),
         :ok <- valid_hash?(block),
         :ok <- valid_coinbase?(block),
         :ok <- valid_transactions?(block),
         :ok <- valid_difficulty?(block, difficulty) do
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

  @spec valid_hash?(Block) :: :ok | {:error, {:wrong_hash, {:too_high, String.t(), number}}}
  defp valid_hash?(%{
         index: index,
         previous_hash: previous_hash,
         timestamp: timestamp,
         nonce: nonce,
         hash: hash,
         merkle_root: merkle_root,
         difficulty: difficulty
       }) do
    with :ok <- compare_hash({index, previous_hash, timestamp, nonce, merkle_root}, hash),
         :ok <- fn ->
           if Block.hash_beat_target?(%{hash: hash, difficulty: difficulty}),
             do: :ok,
             else: {:error, {:wrong_hash, {:too_high, hash, difficulty}}}
         end do
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
    coinbase = List.first(transactions)

    with :ok <- (&if(&1 != nil, do: :ok, else: {:error, :no_coinbase})).(coinbase),
         :ok <- is_coinbase?(coinbase),
         :ok <- appropriate_coinbase_output?(transactions, block_index) do
      :ok
    else
      err -> err
    end
  end

  @spec valid_transaction?(Transaction) :: boolean
  def valid_transaction?(%{inputs: inputs}) do
    inputs
    |> Enum.map(fn input ->
      case {Base.decode16(input.addr), Base.decode16(input.signature)} do
        {{:ok, pub}, {:ok, sig}} -> KeyPair.verify_signature(pub, sig, input.txoid)
        _ -> false
      end
    end)
    |> Enum.all?(&(&1 == true))
  end

  @spec valid_transactions?(Block) :: :ok | {:error, :invalid_inputs}
  def valid_transactions?(%{transactions: transactions}) do
    if Enum.all?(transactions, &valid_transaction?(&1)), do: :ok, else: {:error, :invalid_inputs}
  end

  @spec is_coinbase?(Transaction) :: :ok | {:error, {:not_coinbase, String.t()}}
  defp is_coinbase?(tx) do
    if tx.txtype == "COINBASE", do: :ok, else: {:error, {:not_coinbase, tx.txtype}}
  end

  @spec appropriate_coinbase_output?(list, number) :: :ok | {:error, :invalid_coinbase}
  defp appropriate_coinbase_output?([coinbase | transactions], block_index) do
    total_fees = Block.total_block_fees(transactions)
    reward = Block.calculate_block_reward(block_index)
    amount = List.first(coinbase.outputs).amount

    if D.equal?(D.add(total_fees, reward), amount) do
      :ok
    else
      {:error, {:invalid_coinbase, total_fees, reward, amount}}
    end
  end

  @spec valid_difficulty?(Block, number) :: :ok | {:error, {:invalid_difficulty, number, number}}
  def valid_difficulty?(%{difficulty: difficulty}, diff) do
    if difficulty == diff, do: :ok, else: {:error, {:invalid_difficulty, difficulty, diff}}
  end
end
