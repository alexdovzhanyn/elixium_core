defmodule Elixium.Validator do
  alias Elixium.Block
  alias Elixium.Utilities
  alias Elixium.KeyPair
  alias Elixium.Store.Ledger
  alias Elixium.Store.Utxo
  alias Elixium.BlockEncoder
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
    if :binary.decode_unsigned(block.index) == 0 do
      valid_hash?(block, difficulty)
    else
      with :ok <- valid_index(block.index, last_block.index),
           :ok <- valid_prev_hash?(block.previous_hash, last_block.hash),
           :ok <- valid_hash?(block, difficulty),
           :ok <- valid_coinbase?(block),
           :ok <- valid_transactions?(block, pool_check),
           :ok <- valid_block_size?(block) do
        :ok
      else
        err -> err
      end
    end
  end



  @spec valid_index(number, number) :: :ok | {:error, {:invalid_index, number, number}}
  defp valid_index(index, prev_index) when index > prev_index, do: :ok
  defp valid_index(idx, prev), do: {:error, {:invalid_index, prev, idx}}

  @spec valid_prev_hash?(String.t(), String.t()) :: :ok | {:error, {:wrong_hash, {:doesnt_match_last, String.t(), String.t()}}}
  defp valid_prev_hash?(prev_hash, last_block_hash) when prev_hash == last_block_hash, do: :ok
  defp valid_prev_hash?(phash, lbhash), do: {:error, {:wrong_hash, {:doesnt_match_last, phash, lbhash}}}

  @spec valid_hash?(Block, number) :: :ok | {:error, {:wrong_hash, {:too_high, String.t(), number}}}
  defp valid_hash?(b, difficulty) do
    with :ok <- compare_hash(b, b.hash),
         :ok <- beat_target?(b.hash, b.difficulty) do
      :ok
    else
      err -> err
    end
  end

  defp beat_target?(hash, difficulty) do
    if Block.hash_beat_target?(%{hash: hash, difficulty: difficulty}) do
      :ok
    else
      {:error, {:wrong_hash, {:too_high, hash, difficulty}}}
    end
  end

  @spec compare_hash(Block, String.t()) :: :ok | {:error, {:wrong_hash, {:doesnt_match_provided, String.t(), String.t()}}}
  defp compare_hash(block, hash) do
    computed = Block.calculate_block_hash(block)

    if computed == hash do
      :ok
    else
      {:error, {:wrong_hash, {:doesnt_match_provided, computed, hash}}}
    end
  end

  @spec valid_coinbase?(Block) :: :ok | {:error, :no_coinbase}
  def valid_coinbase?(%{transactions: transactions, index: block_index}) do
    coinbase = hd(transactions)

    with :ok <- coinbase_exist?(coinbase),
         :ok <- is_coinbase?(coinbase),
         :ok <- appropriate_coinbase_output?(transactions, block_index) do
      :ok
    else
      err -> err
    end
  end

  def coinbase_exist?(nil), do: {:error, :no_coinbase}
  def coinbase_exist?(_coinbase), do: :ok

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
        pub = KeyPair.address_to_pubkey(input.addr)
        {:ok, sig} = Base.decode16(input.signature)
        # Check if this UTXO has a valid signature
        KeyPair.verify_signature(pub, sig, input.txoid)
      else
        false
      end
    end)
    |> Enum.all?()
  end

  @spec valid_transactions?(Block, function) :: :ok | {:error, :invalid_inputs}
  def valid_transactions?(%{transactions: transactions}, pool_check \\ &Utxo.in_pool?/1) do
    if Enum.all?(transactions, &valid_transaction?(&1, pool_check)), do: :ok, else: {:error, :invalid_inputs}
  end

  @spec is_coinbase?(Transaction) :: :ok | {:error, {:not_coinbase, String.t()}}
  defp is_coinbase?(%{txtype: "COINBASE"}), do: :ok
  defp is_coinbase?(tx), do: {:error, {:not_coinbase, tx.txtype}}

  @spec appropriate_coinbase_output?(list, number) :: :ok | {:error, :invalid_coinbase}
  defp appropriate_coinbase_output?([coinbase | transactions], block_index) do
    total_fees = Block.total_block_fees(transactions)

    reward =
      block_index
      |> :binary.decode_unsigned()
      |> Block.calculate_block_reward()

    amount = hd(coinbase.outputs).amount

    if D.equal?(D.add(total_fees, reward), amount) do
      :ok
    else
      {:error, {:invalid_coinbase, total_fees, reward, amount}}
    end
  end

  @spec valid_timetamp?(Block) :: :ok | {:error, :timestamp_too_high}
  defp valid_timetamp?(%{timestamp: timestamp}) do
    ftl = Application.get_env(:elixium_core, :future_time_limit)

    current_time =
      DateTime.utc_now()
      |> DateTime.to_unix()

    if timestamp < current_time + ftl, do: :ok, else: {:error, :timestamp_too_high}
  end

  @spec valid_block_size?(Block) :: {:ok} | {:error, :block_too_large}
  defp valid_block_size?(block) do
    block_size_limit = Application.get_env(:elixium_core, :block_size_limit)

    under_size_limit =
      block
      |> BlockEncoder.encode()
      |> byte_size()
      |> Kernel.<=(block_size_limit)

    if under_size_limit, do: :ok, else: {:error, :block_too_large}
  end
end
