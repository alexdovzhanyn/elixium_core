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

  @doc """
    Gets an option that was passed in as a command line argument
  """
  @spec get_arg(atom, any) :: String.t()
  def get_arg(arg, not_found \\ nil), do: Map.get(args(), arg, not_found)

  def args do
    :init.get_plain_arguments()
    |> Enum.at(1)
    |> List.to_string()
    |> String.split("--")
    |> Enum.filter(& &1 != "")
    |> Enum.map(fn a ->
         kv =
           a
           |> String.trim()
           |> String.replace("=", " ")
           |> String.replace(~r/\s+/, " ")
           |> String.split(" ")

         case kv do
           [key, value] -> {String.to_atom(key), value}
           [key] -> {String.to_atom(key), true}
         end
       end)
    |> Map.new()
  end
end
