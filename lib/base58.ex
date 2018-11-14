defmodule Base58 do
  @alphabet '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

  @moduledoc """
    Provides functionality for encoding and decoding in Base58
  """

  def encode(data, hash \\ "")

  def encode(data, hash) when is_binary(data) do
    encode_zeros(data) <> encode(:binary.decode_unsigned(data), hash)
  end

  def encode(0, hash), do: hash

  def encode(data, hash) do
    character = <<Enum.at(@alphabet, rem(data, 58))>>

    data
    |> div(58)
    |> encode(character <> hash)
  end

  defp encode_zeros(data) do
    <<Enum.at(@alphabet, 0)>>
    |> String.duplicate(leading_zeros(data))
  end

  defp leading_zeros(data) do
    data
    |> :binary.bin_to_list()
    |> Enum.find_index(&(&1 != 0))
  end

  def decode(dec, acc \\ 0)

  def decode("", acc), do: :binary.encode_unsigned(acc)

  def decode(<<char::utf8, rest::binary>>, acc) do
    decode(rest, (acc * 58) + Enum.find_index(@alphabet, &(&1 == char)))
  end
end
