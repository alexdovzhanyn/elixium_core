defmodule Elixium.Pool.Orphan do
  @moduledoc """
    Convinient interface functions for interacting with fork blocks
  """

  @pool_name :orphan_pool

  def init, do: :ets.new(@pool_name, [:set, :public, :named_table])

  @spec add(Elixium.Blockchain.Block) :: none
  def add(block), do: :ets.insert(@pool_name, {block.index, block})

  @doc """
    Returns a list of all blocks forked at a given height
  """
  @spec blocks_at_height(number) :: list
  def blocks_at_height(height) when is_number(height), do: :ets.lookup(@pool_name, height)
end
