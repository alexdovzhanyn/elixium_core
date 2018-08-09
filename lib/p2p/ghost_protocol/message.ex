defmodule Elixium.P2P.GhostProtocol.Message do

  def build(type, message_map) do
    message =
      message_map
      |> Map.keys()
      |> Enum.reduce("", & reduce_message(&1, &2, message_map))

    type <> message <> "\r\n"
  end

  defp reduce_message(key, acc, message_map) do
    acc <> "|" <> Atom.to_string(key) <> ":" <> Map.get(message_map, key)
  end

end
