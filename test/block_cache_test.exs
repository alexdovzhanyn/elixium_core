defmodule BlockCacheTest do
  alias Elixium.Store.Ledger
  alias Elixium.Blockchain.Block
  use ExUnit.Case, async: true


  test "Block Cache Returns Empty" do
    Elixium.Store.Ledger.initialize
    assert Elixium.Store.Ledger.check_cache_size == 0
  end


  test "Block Cache Inserts Out of Order Block" do
    Elixium.Store.Ledger.initialize
    genesis = Block.initialize()
    block_2 =
      genesis
      |> Block.initialize()
      |> Block.mine()
      |> Map.replace(:index, 2)
      block_1 =
        genesis
        |> Block.initialize()
        |> Block.mine()

      Elixium.Store.Ledger.store(block_2)
      Elixium.Store.Ledger.store(block_1)

      assert Elixium.Store.Ledger.block_cache_validation(block_1) == :ok
  end





end
