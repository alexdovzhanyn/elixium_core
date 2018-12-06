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

  @doc """
    Takes in a list of maps that match %{addr: addr, amount: amount} and creates
    a valid transaction.
  """
  @spec create(list, D.t()) :: Transaction
  def create(designations, fee) do
    utxos = Elixium.Store.Utxo.retrieve_all_utxos()

    # Find total amount of elixir being sent in this transaction
    total_amount = Enum.reduce(designations, D.new(0), fn x, acc -> D.add(x.amount, acc) end)

    # Grab enough UTXOs to cover the total amount plus the fee
    inputs = take_necessary_utxos(utxos, [], D.add(total_amount, fee))

    tx = %Transaction{inputs: inputs}

    tx = Map.put(tx, :id, calculate_hash(tx))

    # UTXO totals will likely exceed the total amount we're trying to send.
    # Let's see what the difference is
    remaining =
      inputs
      |> sum_inputs()
      |> D.sub(D.add(total_amount, fee))

    # If there is any remaining unspent elixir in this transaction, assign it
    # back to an address we control as change
    designations =
      if D.cmp(remaining, D.new(0)) == :gt do
        designations ++ [%{addr: hd(tx.inputs).addr, amount: remaining}]
      else
        designations
      end

    tx = Map.merge(tx, calculate_outputs(tx, designations))

    digest = signing_digest(tx)

    # Create a signature for each unique address in the inputs
    sigs =
      tx.inputs
      |> Enum.uniq_by(& &1.addr)
      |> Enum.map(fn %{addr: addr} ->
        priv = Elixium.KeyPair.get_priv_from_file(addr)
        sig = Elixium.KeyPair.sign(priv, digest)
        {addr, sig}
      end)

    Map.put(tx, :sigs, sigs)
  end

  defp take_necessary_utxos(utxos, chosen, amount) do
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
end
