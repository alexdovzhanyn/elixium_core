defmodule UltraDark do
  alias UltraDark.Blockchain, as: Blockchain
  alias UltraDark.Blockchain.Block, as: Block
  alias UltraDark.Validator, as: Validator
  alias UltraDark.Ledger, as: Ledger

  def initialize do
    Ledger.initialize
    chain = Blockchain.initialize

    main(chain)
  end

  def main(chain) do
    block =
    List.first(chain)
    |> Block.initialize
    |> Block.mine

    IO.puts "\e[34mBlock hash at index #{block.index} calculated:\e[0m #{block.hash}, using nonce: #{block.nonce}"

    case Validator.is_block_valid?(block, chain) do
      :ok -> main(Blockchain.add_block(chain, block))
      {:error, err} ->
        IO.puts err
        main(chain)
    end
  end
end
