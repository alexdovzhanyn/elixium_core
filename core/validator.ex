defmodule UltraDark.Validator do
  alias UltraDark.Blockchain.Block
  alias UltraDark.Utilities
  alias UltraDark.KeyPair

  @doc """
    A block is considered valid if the index is greater than the index of the previous block,
    the previous_hash is equal to the hash of the previous block, and the hash of the block,
    when recalculated, is the same as what the listed block hash is
  """
  @spec is_block_valid?(Block, list) :: :ok | {:error, String.t}
  def is_block_valid?(block, chain) do
    last_block = List.first(chain)

    with :ok <- valid_index(block.index, last_block.index),
       :ok <- valid_prev_hash(block.previous_hash, last_block.hash),
       :ok <- valid_hash(block),
       :ok <- valid_coinbase?(block),
       :ok <- valid_transactions?(block)
    do
      :ok
    else
      err -> err
    end
  end

  defp valid_index(index, prev_index) when index > prev_index, do: :ok
  defp valid_index(index, prev_index) when index <= prev_index, do: {:error, "Block has invalid index"}

  defp valid_prev_hash(prev_hash, last_block_hash) when prev_hash == last_block_hash, do: :ok
  defp valid_prev_hash(prev_hash, last_block_hash) when prev_hash != last_block_hash, do: {:error, "Blocks prev_hash is not equal to the last block's hash"}

  defp valid_hash(%{index: index, previous_hash: previous_hash, timestamp: timestamp, nonce: nonce, hash: hash}) do
    if Utilities.sha_base16([Integer.to_string(index), previous_hash, timestamp, Integer.to_string(nonce)]) == hash, do: :ok, else: {:error, "Block has invalid hash"}
  end

  @spec valid_coinbase?(Block) :: :ok | {:error, String.t}
  def valid_coinbase?(%{transactions: transactions, index: block_index}) do
    coinbase = List.first(transactions)

    with :ok <- (&(if &1 != nil, do: :ok, else: {:error, "Block has no coinbase"})).(coinbase),
       :ok <- is_coinbase?(coinbase),
       :ok <- appropriate_coinbase_output?(transactions, block_index)
    do
      :ok
    else
      err -> err
    end
  end

  @spec valid_transaction?(Transaction) :: boolean
  def valid_transaction?(%{inputs: inputs}) do
    inputs
    |> Enum.map(fn input ->
      {:ok, pub} = input.addr |> Base.decode16
      {:ok, sig} = input.signature |> Base.decode16

      KeyPair.verify_signature(pub, sig, input.txoid)
    end)
    |> Enum.all?(&(&1 == true))
  end

  @spec valid_transactions?(Block) :: :ok | {:error, String.t}
  def valid_transactions?(%{transactions: transactions}) do
    if Enum.all?(transactions, &(valid_transaction? &1)), do: :ok, else: {:error, "Transaction contains invalid input(s)"}
  end

  defp is_coinbase?(tx) do
    if tx.txtype == "COINBASE", do: :ok, else: {:error, "Transaction 1 of block is not of txtype COINBASE"}
  end

  defp appropriate_coinbase_output?([coinbase | transactions], block_index) do
    if Block.total_block_fees(transactions) + Block.calculate_block_reward(block_index) == List.first(coinbase.outputs).amount, do: :ok, else: {:error, "Coinbase output is invalid"}
  end
end
