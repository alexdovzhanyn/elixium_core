defmodule UltraDark do
  alias UltraDark.Blockchain, as: Blockchain
  alias UltraDark.Blockchain.Block, as: Block
  alias UltraDark.Validator, as: Validator

  def initialize do
    chain = Blockchain.initialize

    main(chain)
  end

  def main(chain) do
    block =
    List.first(chain)
    |> Block.initialize
    |> Block.mine

    IO.puts "\e[34mBlock hash calculated:\e[0m #{block.hash}, using nonce: #{block.nonce}"

    if Validator.is_block_valid?(block, chain) do
      main(Blockchain.add_block(chain, block))
    else
      IO.puts "Block Invalid!"
      main(chain)
    end
  end
end
