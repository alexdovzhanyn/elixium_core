defmodule ContractTest do
  use ExUnit.Case, async: true

  test "can create contract" do
    {:ok, src} = File.read("test/fixtures/test_contract.js")

    context =
      src
      |> UltraDark.AST.generate_from_source
      |> UltraDark.AST.remap_with_gamma
      |> ESTree.Tools.Generator.generate
      |> IO.inspect
      |> UltraDark.Contract.prepare_executable
      |> Execjs.compile

    Execjs.exec context.("let c = new MyContract({block_hash: 'wfwefwfwfwfewwf'}); return [c.main(), gamma];")
  end
end
