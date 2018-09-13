defmodule Elixium.Blockchain do
  alias Elixium.Blockchain.Block
  alias Elixium.Store.Ledger
  alias Elixium.Store.Utxo

  @target_blocktime 120
  @diff_rebalance_offset 10_080

  @moduledoc """
    Wrapper functions for interacting with the blockchain on a high level
  """

  @doc """
    Creates a List with a genesis block in it or returns the existing blockchain
  """
  def initialize do
    if Ledger.empty?() do
      add_block(Block.initialize())
    else
      Ledger.retrieve_chain()
    end
  end

  @doc """
    Adds the latest block to the beginning of the blockchain
  """
  @spec add_block(Block) :: none
  def add_block(block) do
    Ledger.append_block(block)
    Utxo.update_with_transactions(block.transactions)
  end

  def recalculate_difficulty do
    count = Ledger.count_blocks() - 1
    if count >= @diff_rebalance_offset - 1 do
      {:ok, last_time, _} = DateTime.from_iso8601(Ledger.last_block.timestamp)
      {:ok, first_time, _} =
        count
        |> min(@diff_rebalance_offset - 1)
        |> Ledger.block_at_height()
        |> IO.inspect
        |> (&(&1.timestamp)).()
        |> DateTime.from_iso8601()

      diff = DateTime.diff(last_time, first_time, :microseconds) / 1_000_000
      avg_secs_per_block = diff / @diff_rebalance_offset
      speed_ratio = @target_blocktime / avg_secs_per_block
      :math.log(speed_ratio) / :math.log(16)
    else
      0
    end
  end

  def diff_rebalance_offset, do: @diff_rebalance_offset
end
