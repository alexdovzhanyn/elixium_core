defmodule Elixium.P2P.GhostProtocol.Parser do
  require IEx

  def parse({:ok, message}) do
    case split_message(message) do
      {:ok, message_type, message_content} -> parameters_to_map(message_content)
      err -> err
    end
  end

  defp parameters_to_map(parameters) do
    parameters
    |> Enum.map(& String.split(&1, ":"))
    |> Map.new(& kvpair_to_tuple(&1))
  end

  defp kvpair_to_tuple([k]) do
    k = String.to_atom(k)
    {k, k}
  end

  defp kvpair_to_tuple([k | v]) do
    value =
      v
      |> List.first()
      |> parse_type()

    key =
      k
      |> String.downcase()
      |> String.to_atom()

    {key, value}
  end

  defp parse_type(param) do
    <<type :: binary-size(1)>> <> value = param

    case type do
      "+" -> parse_type(:int, value)
      "^" -> value
      "*" -> "Not yet implemented"
      _ -> "Failed to parse type"
    end
  end

  defp parse_type(:int, value) do
    {int, _} = Integer.parse(value)
    int
  end

  defp split_message(message) do
    [protocol, bytes, message_type | message_content] = String.split(message, "|")

    with :ok <- valid_protocol?(protocol)
    do
      {:ok, message_type, message_content}
    else err -> err
    end
  end

  defp valid_protocol?("Ghost"), do: :ok
  defp valid_protocol?(p), do: {:error, {:invalid_protocol, p}}
end
