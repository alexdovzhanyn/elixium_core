defmodule Mix.Tasks.Miner do
  use Mix.Task

  def run(_) do
    Miner.initialize
  end
end
