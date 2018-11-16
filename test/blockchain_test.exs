defmodule BlockchainTest do
  alias Elixium.Store.Ledger
  alias Elixium.Block
  alias Elixium.Store.Utxo
  use ExUnit.Case, async: false

  setup _ do
    Ledger.initialize()
    Utxo.initialize()

    on_exit(fn ->
      File.rm_rf!(".chaindata")
      File.rm_rf!(".utxo")
    end)
  end

  test "can initialize a chain" do
    if Elixium.Store.Ledger.empty?() do
      Elixium.Store.Ledger.append_block(Elixium.Block.initialize())
    else
      Elixium.Store.Ledger.hydrate()
    end

    assert [_ | _] = Ledger.retrieve_chain()
  end

  test "can add block to chain" do
    if Elixium.Store.Ledger.empty?() do
      Elixium.Store.Ledger.append_block(Elixium.Block.initialize())
    else
      Elixium.Store.Ledger.hydrate()
    end

    block =
      Ledger.last_block()
      |> Block.initialize()
      |> Block.mine()

    Ledger.append_block(block)
    Utxo.update_with_transactions(block.transactions)

    assert block == Ledger.last_block()
  end

  # test "properly recalculates difficulty" do
  #   {chain, _} = Code.eval_file("test/fixtures/chain.exs")
  #
  #   ets_hydrate = Enum.map(chain, &({&1.index, String.to_atom(&1.hash), &1}))
  #   :ets.insert(:chaindata, ets_hydrate)
  #
  #   assert Blockchain.recalculate_difficulty() == 0
  # end

  test "chain.exs contains valid block hash" do
    {chain, _} = Code.eval_file("test/fixtures/chain.exs")
    ok = chain
    |> Enum.map(& &1.hash == Block.calculate_block_hash(&1))
    |> Enum.all?()
    assert ok
  end

end
