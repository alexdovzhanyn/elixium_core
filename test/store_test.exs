defmodule StoreTest do
  use Elixium.Store
  require Exleveldb
  use ExUnit.Case, async: false

  @store "teststore"
  @store_path Elixium.Store.store_path(@store)

  setup _ do
    on_exit(fn -> File.rm_rf!(@store_path) end)
    :ok
  end

  test "can create a new store" do
    initialize(@store)

    assert File.exists?(@store_path) == true
    File.rm_rf!(@store_path)
  end

  test "can check if store is empty" do
    initialize(@store)
    assert empty?(@store) == true

    File.rm_rf!(@store_path)
  end

  test "can transact with store" do
    initialize(@store)

    assert :ok = transact(@store, do: &Exleveldb.put(&1, :my_key, "the data"))
    File.rm_rf!(@store_path)
  end
end
