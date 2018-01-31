defmodule UltraDark.Ledger do
  require Exleveldb

  def initialize do
    {:ok, ref} = Exleveldb.open(".chaindata") # Generate a new leveldb instance if none exists
    Exleveldb.close(ref) # Immediately close after ensuring creation, we don't need it constantly open
  end

  def append_block(block) do
    within_db_transaction(fn ref ->
      Exleveldb.put(ref, String.to_atom(block.hash), :erlang.term_to_binary(block))
    end)
  end

  def retrieve_block(hash) do
    within_db_transaction(fn ref ->
      Exleveldb.get(ref, String.to_atom(hash))
    end)
  end

  defp within_db_transaction(function) do
    {:ok, ref} = Exleveldb.open(".chaindata")
    function.(ref)
    Exleveldb.close(ref)
  end
end
