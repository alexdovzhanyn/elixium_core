defmodule Elixium.BlockEncoder do
  alias Elixium.Block

  @moduledoc """
    Provides functionality for encoding and decoding blocks
  """

  @encoding_order [
    :index, :hash, :previous_hash,
    :merkle_root, :timestamp, :nonce,
    :difficulty, :version, :transactions
  ]

  @doc """
    Encode a block to a binary representation based on the encoding order:
    @encoding_order
  """
  @spec encode(Block) :: binary
  def encode(block) do
    block = Map.delete(block, :__struct__)
    Enum.reduce(@encoding_order, <<>>, fn attr, bin -> encode(attr, bin, block[attr]) end)
  end

  defp encode(:difficulty, bin, value) do
    # Convert to binary and strip out ETF bytes (we dont need them for storage,
    # we can add them back in when we need to read)
    <<131, 70, difficulty::binary>> = :erlang.term_to_binary(value)

    bin <> difficulty
  end

  defp encode(:transactions, bin, value) do
    # Add transactions in as raw ETF encoding for easy decoding later
    bin <> :erlang.term_to_binary(value)
  end

  defp encode(:hash, bin, value), do: b16encode(bin, value)

  defp encode(:previous_hash, bin, value), do: b16encode(bin, value)

  defp encode(:merkle_root, bin, value), do: b16encode(bin, value)

  defp encode(_attr, bin, value) when is_binary(value) do
    bin <> value
  end

  defp encode(_attr, bin, value) when is_number(value) do
    bin <> :binary.encode_unsigned(value)
  end

  defp b16encode(bin, value), do: bin <> Base.decode16!(value)

  @doc """
    Decode a block from binary that was previously encoded by encode/1
  """
  @spec decode(binary) :: Block
  def decode(block_binary) do
    <<index::bytes-size(4),
      hash::bytes-size(32),
      previous_hash::bytes-size(32),
      merkle_root::bytes-size(32),
      timestamp::bytes-size(4),
      nonce::bytes-size(8),
      difficulty::bytes-size(8),
      version::bytes-size(2),
      transactions::binary
    >> = block_binary

    %Block{
      index: index,
      hash: Base.encode16(hash),
      previous_hash: Base.encode16(previous_hash),
      merkle_root: Base.encode16(merkle_root),
      timestamp: :binary.decode_unsigned(timestamp),
      nonce: nonce,
      difficulty: :erlang.binary_to_term(<<131, 70>> <> difficulty),
      version: version,
      transactions: :erlang.binary_to_term(transactions)
    }
  end
end
