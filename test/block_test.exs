defmodule BlockTest do
  alias Elixium.Block
  alias Elixium.Transaction
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
    assert Block.calculate_block_reward(1) == 7610344284
    assert Block.calculate_block_reward(200_000) == 7031173118
    assert Block.calculate_block_reward(175_000) == 7103569876
    assert Block.calculate_block_reward(3_000_000) == 0
  end

  test "can calculate block fees" do
    transactions = [
      %Transaction{
        inputs: [
          %{txoid: "sometxoid", amount: 210_000_000},
          %{txoid: "othertxoid", amount: 1232300000}
        ],
        outputs: [
          %{txoid: "atxoid", amount: 1_120_000_000}
        ]
      },
      %Transaction{
        inputs: [
          %{txoid: "bleh", amount: 10_000_000},
          %{txoid: "meh", amount: 130_000_000}
        ],
        outputs: [
          %{txoid: "atxoid", amount: 140_000_000}
        ]
      }
    ]

    total_fees = Block.total_block_fees(transactions)
    refute total_fees == 1_582_300_000
  end
end
