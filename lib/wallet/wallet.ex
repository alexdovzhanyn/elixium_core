defmodule UltraDark.Wallet do
  alias UltraDark.Transaction, as: Transaction
  alias UltraDark.Utilities, as: Utilities

  def new_transaction(address, amount, fee)  do
    tx = %Transaction{
      designations: [%{amount: amount, addr: address}],
      inputs: [%{amount: 2, txoid: 'wewfwefwe:1'}, %{amount: 2, txoid: 'wewfwefwe:1'}],
      timestamp: DateTime.utc_now |> DateTime.to_string
    }

    # The transaction ID is just the merkle root of all the inputs, concatenated with the timestamp
    id =
    Transaction.calculate_hash(tx) <> tx.timestamp
    |> (&(Utilities.sha_base16 &1)).()

    tx = %{tx | id: id}

    tx = Map.merge(tx, Transaction.calculate_outputs(tx))
  end

end
