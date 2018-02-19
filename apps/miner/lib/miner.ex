defmodule Miner do
  alias UltraDark.Blockchain
  alias UltraDark.Blockchain.Block
  alias UltraDark.Validator
  alias UltraDark.Ledger
  alias UltraDark.Transaction
  alias UltraDark.UtxoStore
  alias UltraDark.Utilities

  def initialize(address) do
    Ledger.initialize
    UtxoStore.initialize
    chain = Blockchain.initialize

    main(chain, address, List.first(chain).difficulty)
  end

  def main(chain, address, difficulty) do
    block =
      List.first(chain)
      |> Block.initialize

    difficulty =
      if rem(block.index, Blockchain.diff_rebalance_offset) == 0 do
        new_difficulty = Blockchain.recalculate_difficulty(chain) + difficulty
        IO.puts "Difficulty recalculated! Changed from #{difficulty} to #{new_difficulty}"
        new_difficulty
      else
        difficulty
      end

    block = %{block | difficulty: difficulty}

    IO.write("Mining block #{block.index}...\r")

    before = :os.system_time

    block =
      block
      |> calculate_coinbase_amount
      |> Transaction.generate_coinbase(address)
      |> merge_block(block)
      |> Block.mine

    blue = "\e[34m"
    clear = "\e[0m"
    elapsed = (:os.system_time - before) / 1000000000

    IO.puts "#{blue}Index:#{clear} #{block.index} #{blue}Hash:#{clear} #{block.hash} #{blue}Nonce:#{clear} #{block.nonce} #{blue}Elapsed:#{clear} #{elapsed}s #{blue}Hashrate:#{clear} #{block.nonce / elapsed}H/s"

    case Validator.is_block_valid?(block, chain, difficulty) do
      :ok -> main(Blockchain.add_block(chain, block), address, difficulty)

      {:error, err} ->
        IO.puts err
        main(chain, address, difficulty)
    end
  end

  defp calculate_coinbase_amount(block) do
    Block.calculate_block_reward(block.index) + Block.total_block_fees(block.transactions)
  end

  defp merge_block(coinbase, block) do
    new_transactions = [coinbase | block.transactions]
    txoids = Enum.map(new_transactions, &(&1.id))

    Map.merge(block, %{
      transactions: new_transactions,
      merkle_root: Utilities.calculate_merkle_root(txoids)
    })
  end
end
