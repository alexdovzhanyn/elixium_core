defmodule Elixium.Store do
  require Exleveldb

  @moduledoc """
    Provides convinience methods for interacting with LevelDB 
  """

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  def initialize(store) do
    # Generate a new leveldb instance if none exists
    {:ok, ref} = Exleveldb.open(store)
    # Immediately close after ensuring creation, we don't need it constantly open
    Exleveldb.close(ref)
  end

  @doc """
    We don't want to have to remember to open and keep a reference to the leveldb instance
    each time we interact with the chain. Let's make a wrapper that does this for us
  """
  defmacro transact(store, do: block) do
    quote bind_quoted: [store: store, block: block] do
      {:ok, ref} = Exleveldb.open(store)
      result = block.(ref)
      Exleveldb.close(ref)
      result
    end
  end

  def empty?(store) do
    transact store do
      &Exleveldb.is_empty?(&1)
    end
  end
end
