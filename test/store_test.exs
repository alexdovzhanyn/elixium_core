defmodule StoreTest do
  use UltraDark.Store
  require Exleveldb
  use ExUnit.Case, async: true

  @store ".teststore"

  setup _ do
    on_exit(fn -> File.rm_rf!(@store) end)
    :ok
  end

  test "can create a new store" do
    initialize(@store)
    assert File.exists?(@store) == true
  end

  test "can check if store is empty" do
    initialize(@store)
    assert empty?(@store) == true
  end

  test "can transact with store" do
    initialize(@store)

    assert :ok = transact(@store, do: &Exleveldb.put(&1, :my_key, "the data"))
  end
end
