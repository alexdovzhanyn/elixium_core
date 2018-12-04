defmodule BlockTest do
  alias Elixium.Block
  alias Elixium.Transaction
  alias Elixium.Utilities
  alias Decimal, as: D
  use ExUnit.Case, async: false




  test "can create a genesis block" do
    block = Block.initialize()

    genesis = catch_exit(exit Block.mine(block))

    assert :binary.decode_unsigned(genesis.index) == 0
    assert genesis.hash == Block.calculate_block_hash(genesis)
    assert :binary.decode_unsigned(genesis.version) == 0
  end

  test "can create a new empty block" do
    genesis = Block.initialize()
    block = Block.initialize(genesis)

    assert :binary.decode_unsigned(block.index) == :binary.decode_unsigned(genesis.index) + 1
    assert block.previous_hash == genesis.hash
    assert :binary.decode_unsigned(block.version) == 0
  end


  test "can mine a block" do
    genesis = Block.initialize()
    block = Block.initialize(genesis)

    block = catch_exit(exit Block.mine(block))

    assert block.hash != nil
  end

  test "can properly calculate target with integer difficulty" do
    difficulty0 =
      1
      |> Block.calculate_target()
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty1 =
      100_000
      |> Block.calculate_target()
      |> :binary.encode_unsigned()
      |> Base.encode16()

    difficulty2 =
      1_000_000_000
      |> Block.calculate_target()
      |> :binary.encode_unsigned()
      |> Base.encode16()

    assert difficulty0 == "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty1 == "A7C5AC471B4787FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty2 == "044B82FA09B5A53FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
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

    assert difficulty0 == "C1F07C1F07C1EFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty1 == "2585F625AAA801FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    assert difficulty2 == "041DA22928559B7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
  end

  test "can correctly calculate block reward" do
    assert :gt == D.cmp(Block.calculate_block_reward(1), D.new(761))
    assert :gt == D.cmp(Block.calculate_block_reward(200_000), D.new(703))
    assert :gt == D.cmp(Block.calculate_block_reward(175_000), D.new(710))
    assert D.equal?(Block.calculate_block_reward(3_000_000), D.from_float(0.0))
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

    total_fees = Block.total_block_fees(transactions)
    refute D.equal?(total_fees, D.new(158.23))
  end
end
