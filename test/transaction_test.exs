defmodule TransactionTest do
  alias Elixium.Transaction
  alias Elixium.Block
  alias Elixium.Utilities
  alias Elixium.KeyPair
  alias Elixium.Store.Utxo
  use ExUnit.Case, async: false

  @store "keys"

  setup do
    on_exit(fn ->
      File.rm_rf!(Elixium.Store.store_path("chaindata"))
      File.rm_rf!(Elixium.Store.store_path("utxo"))
      File.rm_rf!(Elixium.Store.store_path("keys"))
    end)
  end

  test "can generate a coinbase transaction" do
    %{
      txtype: txtype,
      outputs: outputs
    } = Transaction.generate_coinbase(1223, "some miner address")

    assert txtype == "COINBASE"
    assert length(outputs) == 1
    assert hd(outputs).amount == 1223
  end

  test "id of transaction is merkle root of its inputs" do
    tx = %Transaction{
      inputs: [
        %{txoid: "123"},
        %{txoid: "343"},
        %{txoid: "wef23"}
      ]
    }

    tx = %{tx | id: Transaction.calculate_hash(tx)}

    assert tx.id == "F18A8A34A5FAC83AC915329F8237B972EFF929E1AF6E929E6AC586AF32B2ED43"
  end


  test "Main Create Transaction function creates a valid transaction" do
    #Start the helpers up
    Elixium.Store.Oracle.start_link(Elixium.Store.Utxo)
    Elixium.Store.Oracle.start_link(Elixium.Store.Ledger)
    Elixium.Store.Ledger.initialize()
    Elixium.Store.Utxo.initialize()

    #Generate a New KeyPair to use for testing
    path = Elixium.Store.store_path(@store)
    {public, _private} = KeyPair.create_keypair
    compressed_pub_address = KeyPair.address_from_pubkey(public)

    #Initialize the block with the correct information allowing a succesfull transaction to be processed using the new blocks utxo's
    block = Block.initialize()
    block = Map.put(block, :transactions, [])
    index = :binary.decode_unsigned(block.index)
    coin_base = Block.calculate_block_reward(index) + Block.total_block_fees(block.transactions)
    coinbase = Transaction.generate_coinbase(coin_base, compressed_pub_address)
    transactions = [coinbase | block.transactions]
    txdigests = Enum.map(transactions, &:erlang.term_to_binary/1)
    block = Map.merge(block, %{
      transactions: transactions,
      merkle_root: Utilities.calculate_merkle_root(txdigests)
    })
    block = catch_exit(exit Block.mine(block))

    #Append the new block to the store & update the utxo's
    Elixium.Store.Ledger.append_block(block)
    Utxo.update_with_transactions(block.transactions)

    input_designations = [%{amount: 1_000_000_000, addr: "EX08wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKA"}]
    transaction = Transaction.create(input_designations, 10_000_000)

    transaction_input = List.first(transaction.inputs).amount

    outputs_has_own_address? = transaction.outputs |> Enum.any?(& &1.addr == compressed_pub_address)
    outputs_has_send_address? = transaction.outputs |> Enum.any?(& &1.addr == "EX08wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKA")
    outputs_has_correct_value? = transaction.outputs |> Enum.reduce(0, & &1.amount + &2)

    assert Elixium.Validator.valid_transaction?(transaction) == :ok
    assert outputs_has_correct_value? == transaction_input - 10_000_000
    assert outputs_has_own_address? == true
    assert outputs_has_send_address? == true

    key_path = "#{path}/#{compressed_pub_address}.key"
    File.rm!(key_path)
  end





end
