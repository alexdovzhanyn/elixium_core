defmodule Elixium.Transaction do
  alias Elixium.Transaction
  alias Elixium.Utilities
  alias Decimal, as: D

  @moduledoc """
    Contains all the functions that pertain to creating valid transactions
  """

  defstruct id: nil,
            inputs: [],
            outputs: [],
            # Most transactions will be pay-to-public-key
            txtype: "P2PK"

  @spec calculate_outputs(Transaction, Map) :: %{outputs: list, fee: Decimal}
  def calculate_outputs(transaction, designations) do


    fee = calculate_fee(transaction, designations)

    outputs =
      designations
      |> Enum.with_index()
      |> Enum.map(fn {designation, idx} ->
        %{
          txoid: "#{transaction.id}:#{idx}",
          addr: designation.addr,
          amount: designation.amount
        }
      end)

    %{outputs: outputs}
  end

  @doc """
    Each transaction consists of multiple inputs and outputs. Inputs to any
    particular transaction are just outputs from other transactions. This is
    called the UTXO model. In order to efficiently represent the UTXOs within
    the transaction, we can calculate the merkle root of the inputs of the
    transaction.
  """
  @spec calculate_hash(Transaction) :: String.t()
  def calculate_hash(transaction) do
    transaction.inputs
    |> Enum.map(& &1.txoid)
    |> Utilities.calculate_merkle_root()
  end

  @doc """
    In order for a block to be considered valid, it must have a coinbase as the
    FIRST transaction in the block. This coinbase has a single output, designated
    to the address of the miner, and the output amount is the block reward plus
    any transaction fees from within the transaction
  """
  @spec generate_coinbase(Decimal, String.t()) :: Transaction
  def generate_coinbase(amount, miner_address) do
    timestamp = DateTime.utc_now()
    txid = Utilities.sha_base16(miner_address <> timestamp)

    %Transaction{
      id: txid,
      txtype: "COINBASE",
      outputs: [
        %{txoid: "#{txid}:0", addr: miner_address, amount: amount}
      ]
    }
  end

  @spec sum_inputs(list) :: Decimal
  def sum_inputs(inputs) do
    Enum.reduce(inputs, D.new(0), fn %{amount: amount}, acc -> D.add(amount, acc) end)
  end

  @spec calculate_fee(Transaction) :: Decimal
  def calculate_fee(transaction) do
    D.sub(sum_inputs(transaction.inputs), sum_inputs(transaction.outputs))
  end
end
