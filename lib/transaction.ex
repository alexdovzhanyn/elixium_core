defmodule Elixium.Transaction do
  alias Elixium.Transaction
  alias Elixium.Utilities
  alias Elixium.Utxo
  alias Decimal, as: D

  @moduledoc """
    Contains all the functions that pertain to creating valid transactions
  """

  defstruct id: nil,
            inputs: [],
            outputs: [],
            sigs: [],
            # Most transactions will be pay-to-public-key
            txtype: "P2PK"

  @spec calculate_outputs(Transaction, Map) :: %{outputs: list, fee: Decimal}
  def calculate_outputs(transaction, designations) do
    outputs =
      designations
      |> Enum.with_index()
      |> Enum.map(fn {designation, idx} ->
        %Utxo{
          txoid: "#{transaction.id}:#{idx}",
          addr: designation.addr,
          amount: designation.amount
        }
      end)

    %{outputs: outputs}
  end

  @doc """
  Creates a correct tx id
  """
  @spec create_tx_id(List) :: String.t()
  def create_tx_id(tx) do
    calculate_hash(tx)
    |> Utilities.sha_base16()
  end

  @doc """
  Creates a singature list
  """
  @spec create_sig_list(List, Map) :: List
  def create_sig_list(inputs, transaction) do
    Enum.uniq_by(inputs, fn input -> input.addr end)
    |> Enum.map(fn address -> create_sig(address, transaction) end)
  end

  @doc """
  Creates a singature address being passed in and the corresponding private key
  """
  @spec create_sig(String.t(), Map) :: Tuple
  def create_sig(address, transaction) do
    priv = Elixium.KeyPair.get_priv_from_file(address)
    digest = Elixium.Transaction.signing_digest(transaction)
    sig = Elixium.KeyPair.sign(priv, digest)
    {address, sig}
  end

  @doc """
  Take the correct amount of Utxo's to send the alloted amount in a transaction.
  """
  @spec take_necessary_utxos(List, Decimal) :: function
  def take_necessary_utxos(utxos, amount), do: take_necessary_utxos(utxos, [], amount)

  @spec take_necessary_utxos(List, List, Decimal) :: List
  def take_necessary_utxos(utxos, chosen, amount) do
    if D.cmp(amount, 0) == :gt do
      if utxos == [] do
        :not_enough_balance
      else
        [utxo | remaining] = utxos
        take_necessary_utxos(remaining, [utxo | chosen], D.sub(amount, utxo.amount))
      end
    else
      chosen
    end
  end

  @doc """
  Creates a current time stamp for transaction building
  """
  @spec create_timestamp :: String.t()
  def create_timestamp, do: DateTime.utc_now |> DateTime.to_string

  @doc """
  # Since a UTXO is fully used up when we put it in a new transaction, we must create a new output
  # that credits us with the change
  """
  @spec create_designations(Map, Decimal, Decimal, String.t(), List) :: List
  def create_designations(inputs, amount, desired_fee, return_address, prev_designations) do
    designations =
      case D.cmp(Transaction.sum_inputs(inputs), D.add(amount, desired_fee)) do
        :gt ->
          [%{amount: D.sub(Transaction.sum_inputs(inputs), D.add(amount, desired_fee)), addr: return_address} | prev_designations]
        :lt -> prev_designations
        :eq -> prev_designations
      end
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
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    txid = Utilities.sha_base16(miner_address <> timestamp)

    %Transaction{
      id: txid,
      txtype: "COINBASE",
      outputs: [
        %Utxo{txoid: "#{txid}:0", addr: miner_address, amount: amount}
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

  @doc """
    Takes in a transaction received from a peer which may have malicious or extra
    attributes attached. Removes all extra parameters which are not defined
    explicitly by the transaction struct.
  """
  @spec sanitize(Transaction) :: Transaction
  def sanitize(unsanitized_transaction) do
    sanitized_transaction = struct(Transaction, Map.delete(unsanitized_transaction, :__struct__))
    sanitized_inputs = Enum.map(sanitized_transaction.inputs, &Utxo.sanitize/1)
    sanitized_outputs = Enum.map(sanitized_transaction.outputs, &Utxo.sanitize/1)

    sanitized_transaction
    |> Map.put(:inputs, sanitized_inputs)
    |> Map.put(:outputs, sanitized_outputs)
  end

  @doc """
    Returns the data that a signer of the transaction needs to sign
  """
  @spec signing_digest(Transaction) :: binary
  def signing_digest(%{inputs: inputs, outputs: outputs, id: id, txtype: txtype}) do
    digest = :erlang.term_to_binary(inputs) <> :erlang.term_to_binary(outputs) <> id <> txtype

    :crypto.hash(:sha256, digest)
  end
end
