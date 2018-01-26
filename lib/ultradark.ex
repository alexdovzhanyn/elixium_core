defmodule UltraDark do
  alias UltraDark.Blockchain, as: Blockchain

  def initialize do
    %{
      :blockchain => Blockchain.initialize
    }
  end
end
