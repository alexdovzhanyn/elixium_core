defmodule BlockchainTest do
  alias Elixium.Blockchain
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
    Blockchain.initialize()
    assert [_ | _] = Ledger.retrieve_chain()
  end

  test "can add block to chain" do
    Blockchain.initialize()

    block =
      Ledger.last_block()
      |> Block.initialize()
      |> Block.mine()

    Blockchain.add_block(block)

    assert block == Ledger.last_block()
  end

  test "properly recalculates difficulty" do
    {chain, _} = Code.eval_file("test/fixtures/chain.exs")

    ets_hydrate = Enum.map(chain, &({&1.index, String.to_atom(&1.hash), &1}))
    :ets.insert(:chaindata, ets_hydrate)

    assert Blockchain.recalculate_difficulty() == 0
  end
end
