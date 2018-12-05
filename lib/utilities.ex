defmodule Elixium.Utilities do
  @moduledoc """
    Various functions that don't need their own module, since theyre used in multiple
    places for different things
  """

  
  def sha256(data),
    do: hash(data, :sha256)

  defp hash(data, algorithm),
    do: :crypto.hash(algorithm, data)

  def sha_base16(input) do
    :sha256
    |> :crypto.hash(input)
    |> Base.encode16()
  end

  def sha3_base16(list) when is_list(list) do
    list
    |> Enum.join()
    |> sha3_base16()
  end

  # Concatintes the list items together to a string, hashes the block header with  keccak sha3 algorithm, return the encoded string
  def sha3_base16(input) do
    :sha3_256
    |> :keccakf1600.hash(input)
    |> Base.encode16()
  end

  @doc """
    The merkle root lets us represent a large dataset using only one string. We can be confident that
    if any of the data changes, the merkle root will be different, which invalidates the dataset
  """
  @spec calculate_merkle_root(list) :: String.t()
  def calculate_merkle_root(list) do
    list
    |> Enum.chunk_every(2)
    |> Enum.map(&sha_base16(&1))
    |> calculate_merkle_root(true)
  end

  def calculate_merkle_root(list, true) when length(list) == 1, do: hd(list)
  def calculate_merkle_root(list, true), do: calculate_merkle_root(list)

  def pad(data, block_size) do
    to_add = block_size - rem(byte_size(data), block_size)
    data <> String.duplicate(<<to_add>>, to_add)
  end

  def zero_pad(bytes, size) do
    String.duplicate(<<0>>, size - byte_size(bytes)) <> bytes
  end
end
