defmodule BlockTest do
  alias Elixium.Blockchain.Block
  alias Elixium.Transaction
  alias Decimal, as: D
  use ExUnit.Case, async: true

  test "can create a genesis block" do
    genesis = Block.initialize()

    assert genesis.index == 0
    assert genesis.hash == "79644A8F062F1BA9F7A32AF2242C04711A634D42F0628ADA6B985B3D21296EEA"
  end

  test "can create a new empty block" do
    genesis = Block.initialize()

    block =
      genesis
      |> Block.initialize()

    assert block.index == genesis.index + 1
    assert block.previous_hash == genesis.hash
  end

  test "can mine a block" do
    genesis = Block.initialize()

    block =
      genesis
      |> Block.initialize()
      |> Block.mine()

    assert block.hash != nil
  end

  test "can properly calculate target with integer difficulty" do
    difficulty0 =
      0
      |> Block.calculate_target()
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty1 =
      1
      |> Block.calculate_target()
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty2 =
      2
      |> Block.calculate_target()
      |> :binary.encode_unsigned()
      |> Base.encode16()

    assert difficulty0 == "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty1 == "0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty2 == "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
  end

  test "can properly calculate target with float difficulty" do
    difficulty0 =
      1.32
      |> Block.calculate_target()
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty1 =
      6.82243
      |> Block.calculate_target()
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty2 =
      62.2
      |> Block.calculate_target()
      |> :binary.encode_unsigned()
      |> Base.encode16()

    assert difficulty0 == "0696B6E3238C7B7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty1 == "1A2D8DDEF4082AFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty2 == "92"
  end

  test "can correctly calculate block reward" do
    assert :gt == D.cmp(Block.calculate_block_reward(1), D.new(761))
    assert :gt == D.cmp(Block.calculate_block_reward(200_000), D.new(703))
    assert :gt == D.cmp(Block.calculate_block_reward(175_000), D.new(710))
    assert D.equal?(Block.calculate_block_reward(3_000_000), D.new(0.0))
  end

  test "can calculate block fees" do
    transactions = [
      %Transaction{
        inputs: [
          %{txoid: "sometxoid", amount: D.new(21)},
          %{txoid: "othertxoid", amount: D.new(123.23)}
        ],
        outputs: [
          %{txoid: "atxoid", amount: D.new(112)}
        ]
      },
      %Transaction{
        inputs: [
          %{txoid: "bleh", amount: D.new(1)},
          %{txoid: "meh", amount: D.new(13)}
        ],
        outputs: [
          %{txoid: "atxoid", amount: D.new(14)}
        ]
      }
    ]

    assert D.equal?(Block.total_block_fees(transactions), D.new(158.23))
  end
end
