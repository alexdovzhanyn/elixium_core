defmodule Elixium.Utxo do
  alias Elixium.Utxo

  defstruct [:addr, :amount, :txoid, :signature]

  @doc """
    Takes in a utxo received from a peer which may have malicious or extra
    attributes attached. Removes all extra parameters which are not defined
    explicitly by the utxo struct.
  """
  @spec sanitize(Utxo) :: Utxo
  def sanitize(unsanitized_utxo) do
    struct(Utxo, Map.delete(unsanitized_utxo, :__struct__))
  end
end
