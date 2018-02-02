defmodule UltraDark.Transaction do
  alias UltraDark.Transaction, as: Transaction
  alias UltraDark.Validator, as: Validator
  alias UltraDark.Utilities, as: Utilities
  defstruct [
    id: nil,
    inputs: [],
    outputs: [],
    fee: 0,
    designations: [],
    timestamp: nil,
    txtype: "P2PK" # Most transactions will be pay-to-public-key
  ]

  def calculate_outputs(transaction) do
    %{designations: designations} = transaction

    fee = calculate_fee(transaction)

    outputs =
    designations
    |> Enum.with_index
    |> Enum.map(fn ({designation, idx}) -> %{txoid: "#{transaction.id}:#{idx}", addr: designation[:addr], amount: designation[:amount]} end)

    %{outputs: outputs, fee: fee}
  end

  @doc """
    Each transaction consists of multiple inputs and outputs. Inputs to any particular transaction are just outputs
    from other transactions. This is called the UTXO model. In order to efficiently represent the UTXOs within the transaction,
    we can calculate the merkle root of the inputs of the transaction.
  """
  def calculate_hash(transaction) do
    transaction.inputs
    |> Enum.map(&(&1[:txoid]))
    |> Utilities.calculate_merkle_root
  end


  @doc """
    In order for a block to be considered valid, it must have a coinbase as the FIRST transaction in the block.
    This coinbase has a single output, designated to the address of the miner, and the output amount is
    the block reward plus any transaction fees from within the transaction
  """
  def generate_coinbase(miner_address, amount) do
    timestamp = DateTime.utc_now |> DateTime.to_string
    txid = Utilities.sha_base16(miner_address <> timestamp)

    %Transaction{
      id: txid,
      txtype: "COINBASE",
      timestamp: timestamp,
      outputs: [
        %{txoid: "#{txid}:0",addr: miner_address, amount: amount}
      ]
    }
  end

  def sum_inputs(inputs) do
    Enum.reduce(inputs, 0, fn (%{amount: amount}, acc) -> amount + acc end)
  end

  def calculate_fee(transaction) do
    sum_inputs(transaction.inputs) - sum_inputs(transaction.designations)
  end
end
