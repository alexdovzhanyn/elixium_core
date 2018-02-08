defmodule UltraDark.Blockchain do
  alias UltraDark.Blockchain.Block
  alias UltraDark.Ledger
  alias UltraDark.UtxoStore

  @doc """
    Creates a List with a genesis block in it or returns the existing blockchain
  """
  def initialize do
    if Ledger.is_empty? do
      add_block([], Block.initialize)
    else
      Ledger.retrieve_chain
    end
  end

  @doc """
    Adds the latest block to the beginning of the blockchain
  """
  @spec add_block(list, Block) :: list
  def add_block(chain, block) do
    chain = [block | chain]

    Ledger.append_block(block)
    UtxoStore.update_with_transactions(block.transactions)

    chain
  end

end
