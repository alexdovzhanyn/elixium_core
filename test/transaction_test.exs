defmodule TransactionTest do
  alias Elixium.Transaction
  alias Elixium.Block
  alias Elixium.Utilities
  alias Elixium.KeyPair
  alias Elixium.Store.Utxo
  alias Decimal, as: D
  use ExUnit.Case, async: false

  @store "test_keys"

  setup do
      Application.put_env(:elixium_core, :unix_key_address, "/test_keys")

      on_exit(fn ->
        File.rm_rf!(".chaindata")
        File.rm_rf!(".utxo")
        File.rm_rf!("keys")
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

  test "Transaction Generates Correct Designations & Outputs" do
    input_amount = D.new(760.0)
    input_designations = [%{amount: D.new(100), addr: "EX08wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKA"}]
    utxos = [%Elixium.Utxo{addr: "EX04wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKQ", amount: D.new(760.0), txoid: "123"}]
    inputs = utxos

    output_amount = Decimal.new(100)

    designations = Transaction.create_designations(inputs, output_amount, D.new(1.0), "EX04wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKQ", input_designations)
    tx_timestamp = Elixium.Transaction.create_timestamp
    tx =
      %Elixium.Transaction{
        inputs: inputs
      }

    id = Elixium.Transaction.create_tx_id(tx, tx_timestamp)
    tx = %{tx | id: id}
    outputs = Transaction.calculate_outputs(tx, designations)

    designations_has_own_address? = designations |> Enum.any?(fn utxo -> utxo.addr == "EX04wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKQ" end)
    designations_has_send_address? = designations |> Enum.any?(fn utxo -> utxo.addr == "EX08wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKA" end)
    designations_has_correct_value? = designations |> Enum.reduce(D.new(0), fn utxo, acc ->  D.add(acc, utxo.amount) end)
    outputs_has_own_address? = outputs.outputs |> Enum.any?(fn utxo -> utxo.addr == "EX04wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKQ" end)
    outputs_has_send_address? = outputs.outputs |> Enum.any?(fn utxo -> utxo.addr == "EX08wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKA" end)
    outputs_has_correct_value? = outputs.outputs |> Enum.reduce(D.new(0), fn utxo, acc ->  D.add(acc, utxo.amount) end)

    assert designations_has_correct_value? == D.sub(input_amount, D.new(1.0))
    assert designations_has_own_address? == true
    assert designations_has_send_address? == true
    assert outputs_has_correct_value? == D.sub(input_amount, D.new(1.0))
    assert outputs_has_own_address? == true
    assert outputs_has_send_address? == true
  end

  test "Correct Transaction is Built and Verified" do
    #Start the helpers up
    Elixium.Store.Oracle.start_link(Elixium.Store.Utxo)
    Elixium.Store.Oracle.start_link(Elixium.Store.Ledger)
    Elixium.Store.Ledger.initialize()
    Elixium.Store.Utxo.initialize()

    #Generate a New KeyPair to use for testing
    path = Elixium.Store.store_path(@store)
    {public, private} = KeyPair.create_keypair
    compressed_pub_address = KeyPair.address_from_pubkey(public)

    #Initialize the block with the correct information allowing a succesfull transaction to be processed using the new blocks utxo's
    block = Block.initialize()
    block = Map.put(block, :transactions, [])
    index = :binary.decode_unsigned(block.index)
    coin_base = D.add(Block.calculate_block_reward(index), Block.total_block_fees(block.transactions))
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


    #Here we are getting the mined block from the store to find the UTXO's to use as inputs
    utxos = Elixium.Store.Utxo.find_by_address(compressed_pub_address)
    input_amount = D.new(760.0)
    input_designations = [%{amount: D.new(100), addr: "EX08wxzqyiG4nvJqC9gTHDnmow71h8j7tt2UAGj3GamRibVAEkiKA"}]
    inputs = utxos |> Enum.take(1)
    output_amount = Decimal.new(100)
    designations = Transaction.create_designations(inputs, output_amount, D.new(1.0), compressed_pub_address, input_designations)

    #Bulk of the id functions for the transactions, builds the correct time stamp & outputs
    tx_timestamp = Elixium.Transaction.create_timestamp
    tx =
      %Elixium.Transaction{
        inputs: inputs
      }
    id = Elixium.Transaction.create_tx_id(tx, tx_timestamp)
    tx = %{tx | id: id}
    transaction = Map.merge(tx, Transaction.calculate_outputs(tx, designations))

    #Here we take unique inputs (i.e only uniq compressed addresses) and we're creating a sig list to verify
    sigs =
      Enum.uniq_by(inputs, fn input -> input.addr end)
      |> Enum.map(fn input ->
         Transaction.create_sig_list(input, transaction)
    end)
    transaction = Map.put(transaction, :sigs, sigs)
    assert Elixium.Validator.valid_transaction?(transaction) == true

    #Now lets remove the test key from the system
    key_path = "#{path}/#{compressed_pub_address}.key"
    File.rm!(key_path)
  end





end
