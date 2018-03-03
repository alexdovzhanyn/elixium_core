defmodule BlockchainTest do
  alias UltraDark.{Blockchain, Blockchain.Block}
  use ExUnit.Case, async: true

  setup _ do
    on_exit(fn ->
      File.rm_rf!(".chaindata")
      File.rm_rf!(".utxo")
    end)
  end

  test "can initialize a chain" do
    chain = Blockchain.initialize()
    assert [_ | _] = chain
  end

  test "can add block to chain" do
    chain = Blockchain.initialize()

    block =
      List.first(chain)
      |> Block.initialize()
      |> Block.mine()

    assert [block | chain] == Blockchain.add_block(chain, block)
  end

  test "properly recalculates difficulty" do
    {chain, _} = Code.eval_file("test/fixtures/chain.exs")
    assert Blockchain.recalculate_difficulty(chain) == 4.529592161075461
  end
end
