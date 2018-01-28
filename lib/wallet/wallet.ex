defmodule UltraDark.Wallet do
  alias UltraDark.Transaction, as: Transaction

  def new_transaction(address, amount, fee)  do
    tx = %Transaction{
      designations: [%{amount: 12, addr: 'wfwfwefwef'}, %{amount: 10, addr: 'wefwef'}],
      inputs: [%{amount: 2, txoid: 'wewfwefwe:1'}, %{amount: 2, txoid: 'wewfwefwe:1'}],
      timestamp: DateTime.utc_now |> DateTime.to_string
    }

    # The transaction ID is just the merkle root of all the inputs, concatenated with the timestamp
    id =
    Transaction.calculate_hash(tx) <> tx.timestamp
    |> (fn (h) -> :crypto.hash(:sha256, h) |> Base.encode16 end).()

    tx = %{tx | id: id}

    tx = Map.merge(tx, Transaction.calculate_outputs(tx))
  end

end
