defmodule ContractTest do
  use ExUnit.Case, async: true

  test "can call method from contract with enough gamma" do
    contract_params = %{
      block_hash: "This is a block hash",
      block_index: 1,
      block_nonce: 123_131,
      transaction_id: "Some transaction ID here",
      max_gamma: 10_000
    }

    assert {:ok, _result, _gamma} =
      "test/fixtures/test_contract.js"
      |> UltraDark.Contract.run_contract({"main", []}, contract_params)
  end

  test "can call method from contract that exceeds gamma" do
    contract_params = %{
      block_hash: "This is a block hash",
      block_index: 1,
      block_nonce: 123_131,
      transaction_id: "Some transaction ID here",
      max_gamma: 10_000
    }

    error =
      "test/fixtures/test_contract.js"
      |> UltraDark.Contract.run_contract({"reallyExpensiveFunction", []}, contract_params)

    assert {:error, "Out of Gamma"} = error
  end

  test "can call method from contract with exact gamma" do
    contract_params = %{
      block_hash: "This is a block hash",
      block_index: 1,
      block_nonce: 123_131,
      transaction_id: "Some transaction ID here",
      max_gamma: 7506
    }

    assert {:ok, _result, _gamma} =
      "test/fixtures/test_contract.js"
      |> UltraDark.Contract.run_contract({"main", []}, contract_params)
  end
end
