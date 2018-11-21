defmodule Elixium.Utxo do
  alias Elixium.Utxo

  defstruct [:addr, :amount, :txoid, :signature]

  def sanitize(unsanitized_utxo) do
    struct(Utxo, Map.delete(unsanitized_utxo, :__struct__))
  end
end
