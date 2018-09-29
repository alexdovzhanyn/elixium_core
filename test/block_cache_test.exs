defmodule BlockCacheTest do
  alias Elixium.Store.BlockCache
  alias Elixium.Blockchain.Block
  use ExUnit.Case, async: true

  test "Creates ETS Store" do
    assert Elixium.Store.BlockCache.init() == :block_cache
  end

  test "Inserts into cache correctly" do
    genesis = Block.initialize()
    block =
      genesis
      |> Block.initialize()
      |> Block.mine()
    store = Elixium.Store.BlockCache.init()
    assert Elixium.Store.BlockCache.store(store, block) == :ok
  end

  test "Deletes Block From Cache" do
    genesis = Block.initialize()
    block =
      genesis
      |> Block.initialize()
      |> Block.mine()
    store = Elixium.Store.BlockCache.init()
    Elixium.Store.BlockCache.store(store, block)
    assert Elixium.Store.BlockCache.delete(store, block) == :ok
  end

  test "Check ETS for Forward Block" do
    genesis = Block.initialize()
    block_2 =
      genesis
      |> Block.initialize()
      |> Block.mine()
      |> Map.replace(:index, 2)
    store = Elixium.Store.BlockCache.init()
    Elixium.Store.BlockCache.store(store, block_2)

    block_1 =
      genesis
      |> Block.initialize()
      |> Block.mine()

      assert Elixium.Store.BlockCache.check_block(store, block_2, block_1) == {:up, block_2, block_1}
  end

  test "Check new block gets processed and then verified" do
    genesis = Block.initialize()
    block_2 =
      genesis
      |> Block.initialize()
      |> Block.mine()
      |> Map.replace(:index, 2)
    store = Elixium.Store.BlockCache.init()
    Elixium.Store.BlockCache.store(store, block_2)

    block_1 =
      genesis
      |> Block.initialize()
      |> Block.mine()

      return = Elixium.Store.BlockCache.check_block(store, block_2, block_1)
      assert Elixium.Store.BlockCache.check_validation_of_blocks(return) == {:ok, "Validated Forwards", block_2, block_1}
  end

  test "Check After Verification Blocks are removed from ets" do
    genesis = Block.initialize()
    block_2 =
      genesis
      |> Block.initialize()
      |> Block.mine()
      |> Map.replace(:index, 2)
    store = Elixium.Store.BlockCache.init()
    Elixium.Store.BlockCache.store(store, block_2)

    block_1 =
      genesis
      |> Block.initialize()
      |> Block.mine()

      return = Elixium.Store.BlockCache.check_block(store, block_2, block_1)
      result =  Elixium.Store.BlockCache.check_validation_of_blocks(return)

      assert Elixium.Store.BlockCache.remove_blocks(store, result) == :ok
  end



end
