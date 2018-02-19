defmodule StoreTest do
  alias UltraDark.Store
  require Exleveldb
  use ExUnit.Case

  @store ".teststore"

  setup context do
    on_exit fn -> File.rm_rf!(@store) end
    :ok
  end

  test "can create a new store" do
    Store.initialize(@store)
    assert File.exists?(@store) == true
  end

  test "can check if store is empty" do
    Store.initialize(@store)
    assert Store.is_empty?(@store) == true
  end

  test "can transact with store" do
    Store.initialize(@store)

    res =
      fn ref ->
        Exleveldb.put(ref, :my_key, "the data")
      end
      |> Store.transact(@store)

    assert res == :ok
  end

end
