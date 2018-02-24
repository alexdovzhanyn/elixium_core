defmodule ErrorTest do
  alias UltraDark.Error
  use ExUnit.Case, async: true

  test "can stringify invalid index errors" do
    assert Error.to_string({:error, {:invalid_index, 3, 2}}) == "invalid index 2, expected >3"
  end

  test "can stringify invalid hash errors where the hash doesn't match the last hash" do
    assert Error.to_string({:error, {:wrong_hash, {:doesnt_match_last, "a", "b"}}}) ==
             "invalid hash: doesn't match last hash. expected a, got b"
  end

  test "can stringify invalid hash errors where the hash is too low" do
    assert Error.to_string({:error, {:wrong_hash, {:too_low, "a", 5}}}) ==
             "invalid hash: hash a is too low for a difficulty of 5"
  end

  test "can stringify hash errors where the hash was wrongly computed" do
    assert Error.to_string({:error, {:wrong_hash, {:doesnt_match_provided, "a", "b"}}}) ==
             "invalid hash: provided hash b doesn't equal a"
  end

  test "can stringify no coinbase errors" do
    assert Error.to_string({:error, :no_coinbase}) == "no coinbase found in a block"
  end

  test "can stringify invalid transaction input errors" do
    assert Error.to_string({:error, :invalid_inputs}) == "invalid transaction inputs"
  end

  test "can stringify errors where the first transaction isn't a coinbase" do
    assert Error.to_string({:error, {:not_coinbase, "P2PK"}}) ==
             "the first transaction is not a coinbase, but a P2PK"
  end

  test "can stringify invalid coinbase errors" do
    assert Error.to_string({:error, :invalid_coinbase}) ==
             "the coinbase is invalid, since the fees + reward ≠ coinbase amount"
  end

  test "can stringify invalid difficulty errors" do
    assert Error.to_string({:error, {:invalid_difficulty, 5, 10}}) ==
             "invalid block difficulty 5. expected 10"
  end

  test "doesn't crash for invalid arguments" do
    assert Error.to_string("not an error") == "error not an error isn't a valid error tuple"

    assert Error.to_string({:error, 10}) == "unrecognized error: 10"
  end
end
