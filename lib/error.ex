defmodule Elixium.Error do
  @moduledoc """
    Converts error tuples to human-readable strings.
  """

  @doc """
    Converts a tuple in the form {:error, any} to a string.
  """
  @spec to_string({:error, any}) :: String.t()
  def to_string({:error, err}), do: str(err)
  def to_string(err), do: "Error #{inspect(err)} isn't a valid error tuple"

  defp str({:invalid_index, prev, index}),
    do: "Invalid index #{:binary.decode_unsigned(index)}, expected > #{:binary.decode_unsigned(prev)}"
  defp str({:wrong_hash, reason}), do: "Invalid hash: #{hash_err(reason)}"
  defp str(:no_coinbase), do: "No coinbase found in a block"
  defp str(:invalid_inputs), do: "Invalid transaction inputs"

  defp str(:block_too_large), do: "Block too large -- Exceeds byte limit"

  defp str({:not_coinbase, txtype}),
    do: "The first transaction is not a coinbase, but a #{txtype}"

  defp str({:invalid_coinbase, fees, reward, amount}),
    do:
      "The coinbase is invalid, since the fees (#{fees}) + reward (#{reward}) ≠ coinbase amount (#{
        amount
      })"

  defp str({:invalid_difficulty, difficulty, diff}),
    do: "Invalid block difficulty #{difficulty}. expected #{diff}"

  defp str({:invalid_tx_id, expected, received}),
    do: "Invalid transaction id. Calculated #{expected} but got #{received}"

  defp str(:failed_pool_check), do: "Input in transaction was not found in UTXO pool"

  defp str(:sig_set_mismatch), do: "Transaction is missing signature(s)"

  defp str(:invalid_tx_sig), do: "One or more signatures in transaction are invalid"

  defp str(:utxo_amount_not_decimal),
    do: "One or more inputs/outputs in the transaction have an amount that is not of type Decimal"

  defp str({:outputs_exceed_inputs, output_total, input_total}),
    do: "Outputs exceed inputs. Outputs: #{output_total}, Inputs: #{input_total}"

  defp str({:invalid_transaction, errors}), do: Enum.each(errors, &Error.to_string/1)

  defp str(err), do: "Unrecognized error: #{err}"

  defp hash_err({:doesnt_match_last, prev, hash}),
    do: "Doesn't match last hash. expected #{prev}, got #{hash}"

  defp hash_err({:too_high, hash, difficulty}),
    do: "Hash #{hash} is too high for a difficulty of #{difficulty}"

  defp hash_err({:doesnt_match_provided, computed, hash}),
    do: "Provided hash #{hash} doesn't equal #{computed}"
end
