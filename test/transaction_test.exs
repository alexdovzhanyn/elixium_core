defmodule TransactionTest do
  alias Elixium.Transaction
  alias Decimal, as: D
  use ExUnit.Case, async: true

  @pub_address "EX05BQPcYtf5QQdY3Tg1D8V26dcL2xSiLQwPQ7gfosoza2oRjb23L"
  @priv <<40, 140, 66, 226, 148, 195, 152, 147, 168, 84, 149, 133, 39, 152, 147, 196,
  205, 185, 53, 228, 26, 161, 218, 64, 192, 154, 182, 2, 117, 136, 238, 144>>

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
    #Elixium.Store.Ledger.initialize()
    #Elixium.Store.Utxo.initialize()
    #{pub, priv} = Elixium.KeyPair.get_from_private(@priv) |> IO.inspect
    #addr = Elixium.KeyPair.address_from_pubkey(pub) |> IO.inspect
    #utxos = Elixium.Store.Utxo.find_by_address(addr) |> IO.inspect
  end





end
