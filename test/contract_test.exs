defmodule ContractTest do
  use ExUnit.Case, async: true

  test "can create contract" do
    assert ["The hash is: fwe, but the transaction id is: wfe", 7506] =
      "test/fixtures/test_contract.js"
      |> UltraDark.Contract.compile()
      |> UltraDark.Contract.call_method("main")
  end
end
