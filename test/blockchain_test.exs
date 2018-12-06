defmodule BlockchainTest do
  alias Elixium.Store.Ledger
  alias Elixium.Block
  alias Elixium.Store.Utxo
  alias Elixium.Transaction
  alias Elixium.Utilities
  alias Decimal, as: D
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
    block = Block.initialize()
    block = Map.put(block, :transactions, [])
    index = :binary.decode_unsigned(block.index)
    coin_base = D.add(Block.calculate_block_reward(index), Block.total_block_fees(block.transactions))
    coinbase = Transaction.generate_coinbase(coin_base, "EX06BQPcYtf5QQdY3Tg1D8V26dcL2xSiLQwPQ7gfosoza2oRjb23L")
    transactions = [coinbase | block.transactions]
    txdigests = Enum.map(transactions, &:erlang.term_to_binary/1)

    block = Map.merge(block, %{
      transactions: transactions,
      merkle_root: Utilities.calculate_merkle_root(txdigests)
    })
    block = catch_exit(exit Block.mine(block))
    if Ledger.empty?() do
      Ledger.append_block(block)
    else
      Ledger.hydrate()
    end

    assert [_ | _] = Ledger.retrieve_chain()
  end

  test "can add block to chain" do
    #initial Block
    block = Block.initialize()
    block = Map.put(block, :transactions, [])
    index = :binary.decode_unsigned(block.index)
    coin_base = D.add(Block.calculate_block_reward(index), Block.total_block_fees(block.transactions))
    coinbase = Transaction.generate_coinbase(coin_base, "EX06BQPcYtf5QQdY3Tg1D8V26dcL2xSiLQwPQ7gfosoza2oRjb23L")
    transactions = [coinbase | block.transactions]
    txdigests = Enum.map(transactions, &:erlang.term_to_binary/1)
    block = Map.merge(block, %{
      transactions: transactions,
      merkle_root: Utilities.calculate_merkle_root(txdigests)
    })
    block = catch_exit(exit Block.mine(block))
    if Elixium.Store.Ledger.empty?() do
      Elixium.Store.Ledger.append_block(block)
    else
      Elixium.Store.Ledger.hydrate()
    end

    #block we're appending
    block =
      Ledger.last_block()
      |> Block.initialize()
    block = Map.put(block, :transactions, [])
    index = :binary.decode_unsigned(block.index)
    coin_base = D.add(Block.calculate_block_reward(index), Block.total_block_fees(block.transactions))
    coinbase = Transaction.generate_coinbase(coin_base, "EX06BQPcYtf5QQdY3Tg1D8V26dcL2xSiLQwPQ7gfosoza2oRjb23L")
    transactions = [coinbase | block.transactions]
    txdigests = Enum.map(transactions, &:erlang.term_to_binary/1)
    block = Map.merge(block, %{
      transactions: transactions,
      merkle_root: Utilities.calculate_merkle_root(txdigests)
    })
    block = catch_exit(exit Block.mine(block))

    Ledger.append_block(block)
    Utxo.update_with_transactions(block.transactions)

    assert block == Ledger.last_block()
  end

########## MARKING FOR REMOVAL OR ALTERATION BASED ON NEED
   #test "properly recalculates difficulty" do
  #   {chain, _} = Code.eval_file("test/fixtures/chain.exs")
#
  #   ets_hydrate = Enum.map(chain, &({&1.index, String.to_atom(&1.hash), &1}))
  #   :ets.insert(:chaindata, ets_hydrate)
#
  #   assert Block.calculate_difficulty() == 0
  # end

  test "chain.exs contains valid block hash" do
    {chain, _} = Code.eval_file("test/fixtures/chain.exs")

    ok = chain
    |> Enum.map(& &1.hash == Block.calculate_block_hash(&1))
    |> Enum.all?()

    assert ok == false
  end

end
