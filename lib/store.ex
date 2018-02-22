defmodule UltraDark.Store do
  require Exleveldb

  def initialize(store) do
    # Generate a new leveldb instance if none exists
    {:ok, ref} = Exleveldb.open(store)
    # Immediately close after ensuring creation, we don't need it constantly open
    Exleveldb.close(ref)
  end

  @doc """
    We don't want to have to remember to open and keep a reference to the leveldb instance
    each time we interact with the chain. Let's make a wrapper function that does this for us
  """
  def transact(function, store) do
    {:ok, ref} = Exleveldb.open(store)
    result = function.(ref)
    Exleveldb.close(ref)
    result
  end

  def is_empty?(store) do
    fn ref -> Exleveldb.is_empty?(ref) end
    |> transact(store)
  end
end
