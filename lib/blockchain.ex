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
  @spec initialize :: list
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

  @doc """
    Based on the canonical chain, recalculate the difficulty at which blocks should
    be mined. Returns a modifier which must be added to the current difficulty.
    For example, if the current difficulty is 4.0, this function may return something
    like 0.43, and the new difficulty should become 4.43. Conversely, this may also
    return a negative number, which should be treated the same way: a current
    difficulty of 4.0 combined with a return value of -0.43 should produce a new
    difficulty of 3.57
  """
  @spec recalculate_difficulty :: number
  def recalculate_difficulty do
    count = Ledger.count_blocks() - 1
    if count >= @diff_rebalance_offset - 1 do
      last_block = Ledger.last_block
      {:ok, last_time, _} = DateTime.from_iso8601(last_block.timestamp)

      {:ok, first_time, _} =
        last_block.index - rem(last_block.index, @diff_rebalance_offset)
        |> Ledger.block_at_height()
        |> Map.get(:timestamp)
        |> DateTime.from_iso8601()

      do_calculate_difficulty(first_time, last_time)
    else
      0
    end
  end

  @doc """
    Same as recalculate_difficulty/0 except that instead of reading values from
    the ledger, the blocks at the start and end of an epoch are explicitly passed
    in. Although this will work properly otherwise, it is intended that blocks
    passed in have an index which is a multiple of the diff_rebalance_offset
  """
  @spec recalculate_difficulty(Block, Block) :: number
  def recalculate_difficulty(epoch_start, epoch_end) do
    if epoch_end >= @diff_rebalance_offset - 1 do
      {:ok, epoch_end_time, _} = DateTime.from_iso8601(epoch_end.timestamp)
      {:ok, epoch_start_time, _} = DateTime.from_iso8601(epoch_start.timestamp)

      do_calculate_difficulty(epoch_start_time, epoch_end_time)
    else
      0
    end
  end

  def do_calculate_difficulty(epoch_start, epoch_end) do
    avg_secs_per_block =
      epoch_end
      |> DateTime.diff(epoch_start, :microseconds)
      |> Kernel./(1_000_000)
      |> Kernel./(@diff_rebalance_offset)

    @target_blocktime / avg_secs_per_block
    |> :math.log()
    |> Kernel./(:math.log(16))
  end

  def diff_rebalance_offset, do: @diff_rebalance_offset
end
