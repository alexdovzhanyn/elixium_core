defmodule Elixium.Constants do

  @moduledoc """
    Contains constants and functions for calculating certain constants. Mainly
    allows for pre-compile constant generation.
  """

  # Total amount of tokens that will ever exist.
  @total_token_supply 1_000_000_000.0

  # Block at which last block reward will be distributed. Logic behind this
  # number is to have tokens distributed over X period of time. We're going for
  # a total emission period of 10 years. 10 years at 2 minutes per block gives
  # us this 2_628_000 number.
  @block_at_full_emission 2_628_000

  @doc """
    Sigma of the block number @block_at_full_emission. Used in emission algorithm
  """
  def sigma_full_emission_blocks(0), do: 0
  def sigma_full_emission_blocks(n) do
    n + sigma_full_emission_blocks(n - 1)
  end

  def block_at_full_emission, do: @block_at_full_emission

  def total_token_supply, do: @total_token_supply

end
