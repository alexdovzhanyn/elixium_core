defmodule ValidatorTest do
  alias UltraDark.Validator
  alias UltraDark.Blockchain.Block
  alias UltraDark.KeyPair
  alias UltraDark.Transaction
  use ExUnit.Case, async: true

  setup _ do
    on_exit fn -> File.rm_rf!(".keys") end
    :ok
  end

  test "refutes blocks with invalid difficulties" do
    difficulty = 5

    block =
      Block.initialize
      |> Block.initialize

    assert {:error, _} = Validator.valid_difficulty?(block, difficulty)
  end

  test "allows blocks with valid difficulties" do
    block =
      Block.initialize
      |> Block.initialize

    assert :ok = Validator.valid_difficulty?(block, block.difficulty)
  end

  test "can validate a single transaction" do
    {public, private} = KeyPair.create_keypair

    expected_valid_tx = %Transaction{
      inputs: [
        %{txoid: "a", signature: KeyPair.sign(private, "a") |> Base.encode16, addr: public |> Base.encode16},
        %{txoid: "b", signature: KeyPair.sign(private, "b") |> Base.encode16, addr: public |> Base.encode16},
        %{txoid: "c", signature: KeyPair.sign(private, "c") |> Base.encode16, addr: public |> Base.encode16},
      ]
    }

    expected_invalid_tx = %Transaction{
      inputs: [
        %{txoid: "a", signature: KeyPair.sign(private, "a") |> Base.encode16, addr: "a fake address!" |> Base.encode16},
        %{txoid: "b", signature: KeyPair.sign(private, "b") |> Base.encode16, addr: "unencoded fake address!"},
        %{txoid: "c", signature: KeyPair.sign(private, "c") |> Base.encode16, addr: public |> Base.encode16},
      ]
    }

    assert Validator.valid_transaction?(expected_valid_tx)
    refute Validator.valid_transaction?(expected_invalid_tx)
  end
end
