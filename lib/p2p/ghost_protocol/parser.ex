defmodule Elixium.P2P.GhostProtocol.Parser do
  require IEx

  def parse(message) do
    [protocol, bytes, message_type | message_content] = String.split(message, "|")

    parse(message_type, message_content)
  end

  defp parse("HANDSHAKE", message_content) do
    IO.puts "Recieved handshake message."
    parameters = parameters_to_map(message_content)
  end

  defp parameters_to_map(parameters) when is_list(parameters) do
    x =
      parameters
      |> Enum.map(fn p -> kvpair_to_tuple(p) end) # TODO: find a good way to transform bits to strings, but leave strings alone

    IO.puts "Parsed parameters"
  end

  defp parameters_to_map(parameters) do
    parameters
    |> String.split("|")
    |> parameters_to_map
  end

  defp kvpair_to_tuple(pair) do
    [key, value] = String.split(pair, ":")
    {key, value}
  end

end
