defmodule TransactionTest do
  alias UltraDark.Transaction
  alias Decimal, as: D
  use ExUnit.Case, async: true

  test "can generate a coinbase transaction" do
    %{
      txtype: txtype,
      outputs: outputs
    } = Transaction.generate_coinbase(1223, "some miner address")

    assert txtype == "COINBASE"
    assert length(outputs) == 1
    assert List.first(outputs).amount == 1223
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

  test "can generate outputs from designations" do
    tx = %Transaction{
      inputs: [
        %{txoid: "wfwe1d:0", amount: D.new(123.12)},
        %{txoid: "wfwe1d:4", amount: D.new(31.33)},
        %{txoid: "wfwe1d:1", amount: D.new(18)}
      ],
      designations: [
        %{addr: "reciever1", amount: D.new(3)},
        %{addr: "reciever2", amount: D.new(132)}
      ]
    }

    tx = %{tx | id: Transaction.calculate_hash(tx)}

    expected_outputs =  %{
      fee: D.new(37.45),
      outputs: [
        %{
          addr: "reciever1",
          amount: D.new(3),
          txoid: "03E4C4FC8EFCB9F5C03CA73E9A7AA3D60A258B5FC52D7A75C7D0DEF69322A93F:0"
        },
        %{
          addr: "reciever2",
          amount: D.new(132),
          txoid: "03E4C4FC8EFCB9F5C03CA73E9A7AA3D60A258B5FC52D7A75C7D0DEF69322A93F:1"
        }
      ]
    }

    assert Transaction.calculate_outputs(tx) == expected_outputs
  end
end
