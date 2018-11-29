defmodule Elixium.Pool.Orphan do
  @moduledoc """
    Convinient interface functions for interacting with fork blocks
  """

  @pool_name :orphan_pool

  def initialize, do: :ets.new(@pool_name, [:bag, :public, :named_table])

  @spec add(Elixium.Block) :: none
  def add(block), do: :ets.insert(@pool_name, {:binary.decode_unsigned(block.index), block})

  def remove(block) do
    exact_object =
      block.index
      |> :binary.decode_unsigned()
      |> blocks_at_height()
      |> Enum.find(& &1.hash == block.hash)

    if exact_object do
      :ets.delete_object(@pool_name, {:binary.decode_unsigned(exact_object.index), exact_object})
    end
  end

  @doc """
    Returns a list of all blocks forked at a given height
  """
  @spec blocks_at_height(number) :: list
  def blocks_at_height(height) when is_binary(height) do
    height
    |> :binary.decode_unsigned()
    |> blocks_at_height()
  end

  def blocks_at_height(height) when is_number(height) do
    @pool_name
    |> :ets.lookup(height)
    |> Enum.map(fn {_i, blk} -> blk end)
  end

end
