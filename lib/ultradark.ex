defmodule UltraDark do
  alias UltraDark.Blockchain, as: Blockchain
  alias UltraDark.Blockchain.Block, as: Block

  def initialize do
    chain = Blockchain.initialize

    main(chain)
  end

  def main(chain) do
    [head | tail] = chain

    block =
    head
    |> Block.initialize
    |> Block.mine

    IO.puts "\e[34mBlock hash calculated:\e[0m #{block.hash}, using nonce: #{block.nonce}"

    main(Blockchain.add_block(chain, block))
  end
end
