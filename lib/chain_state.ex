defmodule ChainState do
  alias UltraDark.Store
  require Exleveldb

  @moduledoc """
    Stores data related to contracts permanently.
  """

  @store_dir ".chainstate"

  def initialize do
    Store.initialize(@store_dir)
  end
end
