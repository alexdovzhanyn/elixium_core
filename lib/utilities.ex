defmodule UltraDark.Utilities do
  def sha_base16(input), do: :crypto.hash(:sha256, input) |> Base.encode16

  def sha3_base16(list) when is_list(list), do: sha3_base16(Enum.join(list))
  # Concatintes the list items together to a string, hashes the block header with  keccak sha3 algorithm, return the encoded string
  def sha3_base16(input) do
    :keccakf1600.hash(:sha3_256, input)
    |> Base.encode16
  end


  @doc """
    The merkle root lets us represent a large dataset using only one string. We can be confident that
    if any of the data changes, the merkle root will be different, which invalidates the dataset
  """
  @spec calculate_merkle_root(list) :: String.t
  def calculate_merkle_root(list) do
    list
    |> Enum.chunk_every(2)
    |> Enum.map(&(sha_base16 &1))
    |> calculate_merkle_root(true)
  end

  def calculate_merkle_root(list, true) when length(list) == 1, do: List.first(list)
  def calculate_merkle_root(list, true), do: calculate_merkle_root(list)
end
