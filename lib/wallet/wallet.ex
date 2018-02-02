defmodule UltraDark.Wallet do
  alias UltraDark.Transaction, as: Transaction
  alias UltraDark.Utilities, as: Utilities

  def new_transaction(address, amount, desired_fee)  do
    inputs = find_suitable_inputs(amount + desired_fee)
    designations = [%{amount: amount, addr: address}]

    designations = if Transaction.sum_inputs(inputs) > amount + desired_fee do
      # Since a UTXO is fully used up when we put it in a new transaction, we must create a new output
      # that credits us with the change
      [%{amount: Transaction.sum_inputs(inputs) - (amount + desired_fee), addr: "MY OWN ADDR"} | designations]
    else
      designations
    end

    tx =
    %Transaction{
      designations: designations,
      inputs: inputs,
      timestamp: DateTime.utc_now |> DateTime.to_string
    }

    # The transaction ID is just the merkle root of all the inputs, concatenated with the timestamp
    id =
    Transaction.calculate_hash(tx) <> tx.timestamp
    |> (&(Utilities.sha_base16 &1)).()

    tx = %{tx | id: id}
    Map.merge(tx, Transaction.calculate_outputs(tx))
  end

  def find_owned_utxos(public_key) do

  end

  def find_suitable_inputs(amount) do
    [%{amount: 1000, addr: "weffff", txoid: "randomhash:0"}]
  end

end
