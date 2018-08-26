defmodule Elixium.Store.Oracle do
  use GenServer

  @moduledoc """
    Responsible for reading and writing to a given store on behalf
    of other processes. This fixes the issue with LevelDB not allowing
    multiple processes read / write to a store at the same time.
  """

  @doc """
    Start an oracle to interface with a given module. Running an oracle with a
    store will cause it to lock down the store, and no other process will be
    able to communicate with it until the oracle has died.
  """
  @spec start_link(atom) :: {:ok, pid} | {:error, String.t()}
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

  @doc """
    Call a method on the store module of a given oracle. Takes in a reference
    to a started oracle process, and a tuple with the method name, and a list of
    options to pass to the method. E.g. Oracle.inquire(oracle, {:load_known_peers, []})
  """
  @spec inquire(pid, tuple) :: any()
  def inquire(pid, options) do
    GenServer.call(pid, options)
  end

end
