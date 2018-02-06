defmodule Miner do
  alias UltraDark.Blockchain
  alias UltraDark.Blockchain.Block
  alias UltraDark.Validator
  alias UltraDark.Ledger
  alias UltraDark.Transaction
  alias UltraDark.UtxoStore

  def initialize do
    Ledger.initialize
    UtxoStore.initialize
    chain = Blockchain.initialize

    main(chain)
  end

  def main(chain) do
    block =
    List.first(chain)
    |> Block.initialize

    block =
    block
    |> calculate_coinbase_amount
    |> Transaction.generate_coinbase("Some Miner address here")
    |> (fn coinbase -> Map.merge(block, %{transactions: [coinbase | block.transactions]}) end).()
    |> Block.mine

    IO.puts "\e[34mBlock hash at index #{block.index} calculated:\e[0m #{block.hash}, using nonce: #{block.nonce}"

    case Validator.is_block_valid?(block, chain) do
      :ok -> main(Blockchain.add_block(chain, block))
      {:error, err} ->
        IO.puts err
        main(chain)
    end
  end

  defp calculate_coinbase_amount(block) do
    Block.calculate_block_reward(block.index)
  end
end
