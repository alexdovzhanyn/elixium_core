defmodule ValidatorTest do
  alias Elixium.Validator
  alias Elixium.Blockchain.Block
  alias Elixium.KeyPair
  alias Elixium.Transaction
  use ExUnit.Case, async: true

  setup _ do
    on_exit(fn -> File.rm_rf!(".keys") end)
    :ok
  end

  test "can validate a single transaction" do
    {public, private} = KeyPair.create_keypair()

    expected_valid_tx = %Transaction{
      inputs: [
        %{
          txoid: "a",
          signature: private |> KeyPair.sign("a") |> Base.encode16(),
          addr: public |> Base.encode16()
        },
        %{
          txoid: "b",
          signature: private |> KeyPair.sign("b") |> Base.encode16(),
          addr: public |> Base.encode16()
        },
        %{
          txoid: "c",
          signature: private |> KeyPair.sign("c") |> Base.encode16(),
          addr: public |> Base.encode16()
        }
      ]
    }

    expected_invalid_tx = %Transaction{
      inputs: [
        %{
          txoid: "a",
          signature: private |> KeyPair.sign("a") |> Base.encode16(),
          addr: "a fake address!" |> Base.encode16()
        },
        %{
          txoid: "b",
          signature: private |> KeyPair.sign("b") |> Base.encode16(),
          addr: "unencoded fake address!"
        },
        %{
          txoid: "c",
          signature: private |> KeyPair.sign("c") |> Base.encode16(),
          addr: public |> Base.encode16()
        }
      ]
    }

    assert Validator.valid_transaction?(expected_valid_tx)
    refute Validator.valid_transaction?(expected_invalid_tx)
  end

  test "Blocks out of order are correctly validated" do
    genesis = Block.initialize()

    block_1 =
      genesis
      |> Block.initialize()
      |> Block.mine()

    block_2 =
      genesis
      |> Block.initialize()
      |> Block.mine()
      |> Map.replace(:index, 2)

    #assert Validator.is_block_valid?(block_1, 4.0, block_2) == :ok
  end
end
