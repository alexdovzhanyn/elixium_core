defmodule BlockTest do
  alias UltraDark.Blockchain.Block
  alias UltraDark.Transaction
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
    assert D.equal? Block.calculate_block_reward(1), D.new(100)
    assert D.equal? Block.calculate_block_reward(200000), D.new(50)
    assert D.equal? Block.calculate_block_reward(175000), D.new(100)
    assert D.equal? Block.calculate_block_reward(3000000), D.new(0.0030517578125)
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

    assert D.equal? Block.total_block_fees(transactions), D.new(158.23)
  end
end
