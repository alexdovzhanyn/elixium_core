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
    {:ok, ref} =
      store
      |> store_path()
      |> Exleveldb.open()
    # Immediately close after ensuring creation, we don't need it constantly open
    Exleveldb.close(ref) |> IO.inspect
  end

  @doc """
    We don't want to have to remember to open and keep a reference to the leveldb instance
    each time we interact with the chain. Let's make a wrapper that does this for us
  """
  defmacro transact(store, do: block) do
    quote bind_quoted: [store: store, block: block] do
      {:ok, ref} =
        store
        |> store_path()
        |> Exleveldb.open()

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

  def store_path(store) do
    path =
      :elixium_core
      |> Application.get_env(:data_path)
      |> Path.expand()

    if !File.exists?(path) do
      File.mkdir(path)
    end

    "#{path}/#{store}"
  end
end
