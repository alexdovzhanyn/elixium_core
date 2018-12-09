defmodule ErrorTest do
  alias Elixium.Error
  use ExUnit.Case, async: true

  test "can stringify invalid index errors" do
    assert Error.to_string({:error, {:invalid_index, <<0, 0, 0, 3>>, <<0, 0, 0, 2>>}}) == "Invalid index 2, expected > 3"
  end

  test "can stringify invalid hash errors where the hash doesn't match the last hash" do
    assert Error.to_string({:error, {:wrong_hash, {:doesnt_match_last, "a", "b"}}}) ==
             "Invalid hash: Doesn't match last hash. expected a, got b"
  end

  test "can stringify invalid hash errors where the hash is too low" do
    assert Error.to_string({:error, {:wrong_hash, {:too_high, "a", 5}}}) ==
             "Invalid hash: Hash a is too high for a difficulty of 5"
  end

  test "can stringify hash errors where the hash was wrongly computed" do
    assert Error.to_string({:error, {:wrong_hash, {:doesnt_match_provided, "a", "b"}}}) ==
             "Invalid hash: Provided hash b doesn't equal a"
  end

  test "can stringify no coinbase errors" do
    assert Error.to_string({:error, :no_coinbase}) == "No coinbase found in a block"
  end

  test "can stringify invalid transaction input errors" do
    assert Error.to_string({:error, :invalid_inputs}) == "Invalid transaction inputs"
  end

  test "can stringify errors where the first transaction isn't a coinbase" do
    assert Error.to_string({:error, {:not_coinbase, "P2PK"}}) ==
             "The first transaction is not a coinbase, but a P2PK"
  end

  test "can stringify invalid coinbase errors" do
    assert Error.to_string({:error, {:invalid_coinbase, 2, 4, 8}}) ==
             "The coinbase is invalid, since the fees (2) + reward (4) ≠ coinbase amount (8)"
  end

  test "can stringify invalid difficulty errors" do
    assert Error.to_string({:error, {:invalid_difficulty, 5, 10}}) ==
             "Invalid block difficulty 5. expected 10"
  end

  test "doesn't crash for invalid arguments" do
    assert Error.to_string("not an error") == "Error \"not an error\" isn't a valid error tuple"

    assert Error.to_string({:ok, "not an error"}) ==
             "Error {:ok, \"not an error\"} isn't a valid error tuple"

    assert Error.to_string({:error, 10}) == "Unrecognized error: 10"
  end
end
