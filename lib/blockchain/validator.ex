defmodule UltraDark.Validator do
  alias UltraDark.Blockchain.Block, as: Block
  alias UltraDark.Transaction, as: Transaction
  alias UltraDark.Utilities, as: Utilities

  @doc """
    A block is considered valid if the index is greater than the index of the previous block,
    the previous_hash is equal to the hash of the previous block, and the hash of the block,
    when recalculated, is the same as what the listed block hash is
  """
  def is_block_valid?(block, chain) do
    last_block = List.first(chain)

    with :ok <- valid_index(block.index, last_block.index),
       :ok <- valid_prev_hash(block.previous_hash, last_block.hash),
       :ok <- valid_hash(block),
       :ok <- valid_coinbase?(block)
    do
      :ok
    else
      :invalid_index -> (fn -> IO.puts "Block has invalid index"; :error end).()
      :invalid_prev_hash -> (fn -> IO.puts "Block previous_hash is not same as the previous block's hash"; :error end).()
      :invalid_hash -> (fn -> IO.puts "Block header digest does not match hash"; :error end).()
      :no_coinbase -> (fn -> IO.puts "Block does not cointain a coinbase"; :error end).()
      :invalid_coinbase_type -> (fn -> IO.puts "Block coinbase txtype is not COINBASE"; :error end).()
      :invalid_coinbase_output -> (fn -> IO.puts "Block coinbase  output amount is invalid"; :error end).()
    end
  end

  defp valid_index(index, prev_index) when index > prev_index, do: :ok
  defp valid_index(index, prev_index) when index <= prev_index, do: :invalid_index

  defp valid_prev_hash(prev_hash, last_block_hash) when prev_hash == last_block_hash, do: :ok
  defp valid_prev_hash(prev_hash, last_block_hash) when prev_hash != last_block_hash, do: :invalid_prev_hash

  defp valid_hash(%{index: index, previous_hash: previous_hash, timestamp: timestamp, nonce: nonce, hash: hash}) do
    if Utilities.sha_base16([Integer.to_string(index), previous_hash, timestamp, Integer.to_string(nonce)]) == hash, do: :ok, else: :invalid_hash
  end

  def valid_coinbase?(%{transactions: transactions, index: block_index}) do
    coinbase = List.first(transactions)

    with :ok <- (&(if &1 != nil, do: :ok, else: :no_coinbase)).(coinbase),
       :ok <- is_coinbase?(coinbase),
       :ok <- appropriate_coinbase_output?(transactions, block_index)
    do
      :ok
    else
      err -> err
    end
  end

  defp is_coinbase?(tx) do
    if tx.txtype == "COINBASE", do: :ok, else: :invalid_coinbase_type
  end

  defp appropriate_coinbase_output?([coinbase | transactions], block_index) do
    total_block_fees = transactions |> Enum.reduce(0, fn tx, acc -> acc + Transaction.calculate_fee(tx) end)
    appropriate_block_reward = Block.calculate_block_reward(block_index)

    if total_block_fees + appropriate_block_reward == List.first(coinbase.outputs).amount, do: :ok, else: :invalid_coinbase_output
  end
end
