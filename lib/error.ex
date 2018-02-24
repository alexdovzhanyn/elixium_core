defmodule UltraDark.Error do
  @moduledoc """
    Converts error tuples to human-readable strings.
  """

  @doc """
    Converts a tuple in the form {:error, any} to a string.
  """
  @spec to_string({:error, any}) :: String.t
  def to_string({:error, err}), do: str(err)
  def to_string(err), do: "error #{err} isn't a valid error tuple"

  defp str({:invalid_index, prev, index}), do: "invalid index #{index}, expected #{prev+1}"
  defp str({:wrong_hash, reason}), do: "invalid hash: #{hash_err reason}"
  defp str(:no_coinbase), do: "no coinbase found in a block"
  defp str(:invalid_inputs), do: "invalid transaction inputs"
  defp str({:not_coinbase, txtype}), do: "the first transaction is not a coinbase, but a #{txtype}"
  defp str(:invalid_coinbase), do: "the coinbase is invalid, since the fees + reward ≠ coinbase amount"
  defp str({:invalid_difficulty, difficulty, diff}), do: "invalid block difficulty #{difficulty}. expected #{diff}"
  defp str(err), do: "unrecognized error: #{err}"

  defp hash_err({:doesnt_match_last, prev, hash}), do: "doesn't match last hash. expected #{prev}, got #{hash}"
  defp hash_err({:too_low, hash, difficulty}), do: "hash #{hash} is too low for a difficulty of #{difficulty}"
  defp hash_err({:doesnt_match_provided, computed, hash}), do: "provided hash #{hash} doesn't equal #{computed}"
end
