defmodule UltraDark.Blockchain do
  alias UltraDark.Blockchain.Block, as: Block
  alias UltraDark.Ledger, as: Ledger

  @doc """
    Creates a List with a genesis block in it
  """
  def initialize do
    if Ledger.is_empty? do
      [ Block.initialize ]
    else
      Ledger.retrieve_chain
    end
  end

  @doc """
    Adds the latest block to the beginning of the blockchain
  """
  def add_block(chain, block) do
    chain = [block | chain]

    Ledger.append_block(block)

    chain
  end

end
