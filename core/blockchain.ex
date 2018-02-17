defmodule UltraDark.Blockchain do
  alias UltraDark.Blockchain.Block
  alias UltraDark.Ledger
  alias UltraDark.UtxoStore

  @target_blocktime 120
  @diff_rebalance_offset 10080

  @doc """
    Creates a List with a genesis block in it or returns the existing blockchain
  """
  def initialize do
    if Ledger.is_empty?() do
      add_block([], Block.initialize())
    else
      Ledger.retrieve_chain()
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

  def recalculate_difficulty(chain) do
    beginning_index = min(length(chain) - 1, @diff_rebalance_offset - 1)

    last = List.first(chain)
    first = Enum.at(chain, beginning_index)

    diff =
      with {:ok, last_time, _} <- DateTime.from_iso8601(last.timestamp),
           {:ok, first_time, _} <- DateTime.from_iso8601(first.timestamp) do
        diff_µs = DateTime.diff(last_time, first_time, :microseconds)
        diff_s = diff_µs / 1_000_000.0
        avg_secs_per_block = diff_s / @diff_rebalance_offset
        speed_ratio = @target_blocktime / avg_secs_per_block
        :math.log(speed_ratio) / :math.log(16)
      end

    diff
  end

  def diff_rebalance_offset, do: @diff_rebalance_offset
end
