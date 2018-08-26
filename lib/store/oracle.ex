defmodule Elixium.Store.Oracle do
  use GenServer
  require Exleveldb

  @moduledoc """
    Responsible for reading and writing to a given store on behalf
    of other processes. This fixes the issue with LevelDB not allowing
    multiple processes read / write to a store at the same time.
  """

  def start_link(store) do
    GenServer.start_link(__MODULE__, store)
  end

  def init(store_ref) do
    {:ok, store_ref}
  end

  def handle_call({function, options}, _from, store) do
    response_from_store = apply(store, function, options)
    {:reply, response_from_store, store}
  end

  def inquire(pid, options) do
    GenServer.call(pid, options)
  end

end
