defmodule UltraDark.Transaction do
  alias UltraDark.Transaction, as: Transaction
  alias UltraDark.Validator, as: Validator
  defstruct [:id, :inputs, :outputs, :fee, :designations, :timestamp]

  def calculate_outputs(transaction) do
    %{designations: designations} = transaction

    fee = calculate_fee(transaction)

    outputs =
    designations
    |> Enum.with_index
    |> Enum.map(fn ({designation, idx}) -> %{txoid: "#{transaction.id}:#{idx}", addr: designation[:addr], amount: designation[:amount]} end)

    %{outputs: outputs, fee: fee}
  end

  def calculate_hash(transaction) do
    transaction.inputs
    |> Enum.map(fn input -> input[:txoid] end)
    |> Validator.calculate_merkle_root
  end

  defp sum_inputs(inputs) do
    Enum.reduce(inputs, 0, fn (%{amount: amount}, acc) -> amount + acc end)
  end

  defp calculate_fee(transaction) do
    sum_inputs(transaction.inputs) - sum_inputs(transaction.designations)
  end
end
