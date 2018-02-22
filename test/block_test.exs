defmodule BlockTest do
  alias UltraDark.Blockchain.Block
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
      Block.calculate_target(0)
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty1 =
      Block.calculate_target(1)
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty2 =
      Block.calculate_target(2)
      |> :binary.encode_unsigned()
      |> Base.encode16()

    assert difficulty0 == "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty1 == "0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty2 == "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
  end

  test "can properly calculate target with float difficulty" do
    difficulty0 =
      Block.calculate_target(1.32)
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty1 =
      Block.calculate_target(6.82243)
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty2 =
      Block.calculate_target(62.2)
      |> :binary.encode_unsigned()
      |> Base.encode16()

    assert difficulty0 == "0696B6E3238C7B7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty1 == "1A2D8DDEF4082AFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty2 == "92"
  end

  test "can correctly calculate block reward" do
    assert Block.calculate_block_reward(1) == 100
    assert Block.calculate_block_reward(200_000) == 50
    assert Block.calculate_block_reward(175_000) == 100
    assert Block.calculate_block_reward(3_000_000) == 0.0030517578125
  end

  test "can calculate block fees" do
    transactions = [
      %{
        inputs: [
          %{txoid: "sometxoid", amount: 21},
          %{txoid: "othertxoid", amount: 123.23}
        ],
        outputs: [
          %{txoid: "atxoid", amount: 112}
        ]
      },
      %{
        inputs: [
          %{txoid: "bleh", amount: 1},
          %{txoid: "meh", amount: 13}
        ],
        outputs: [
          %{txoid: "atxoid", amount: 14}
        ]
      }
    ]

    # TODO -- we need to represent shades as decimal instead of float because of
    # float arithmetic precision errors in the stdlib

    # assert Block.total_block_fees(transactions) ==
  end
end
