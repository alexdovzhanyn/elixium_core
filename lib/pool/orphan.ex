defmodule Elixium.Pool.Orphan do
  @moduledoc """
    Convinient interface functions for interacting with fork blocks
  """

  @pool_name :orphan_pool

  def initialize, do: :ets.new(@pool_name, [:bag, :public, :named_table])

  @spec add(Elixium.Blockchain.Block) :: none
  def add(block), do: :ets.insert(@pool_name, {block.index, block})

  def remove(block) do
    exact_object =
      block.index
      |> blocks_at_height()
      |> Enum.find(fn {_i, blk} -> blk.hash == block.hash end)

    if exact_object do
      :ets.delete_object(@pool_name, exact_object)
    end
  end

  @doc """
    Returns a list of all blocks forked at a given height
  """
  @spec blocks_at_height(number) :: list
  def blocks_at_height(height) when is_number(height), do: :ets.lookup(@pool_name, height)

end
