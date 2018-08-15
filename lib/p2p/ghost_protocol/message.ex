defmodule Elixium.P2P.GhostProtocol.Message do
  require IEx
  alias Elixium.Utilities

  def build(type, message_map) do
    message = binary_message(type, message_map)
    bytes = message_byte_size(message)

    ["Ghost", bytes, message]
    |> Enum.join("|")
  end

  def build(type, message_map, session_key) do
    message =
      binary_message(type, message_map)
      |> Utilities.pad(32)

    encrypted_message = :crypto.block_encrypt(:aes_ecb, session_key, message)
    bytes = message_byte_size(encrypted_message)

    ["Ghost", bytes, encrypted_message]
    |> Enum.join("|")
  end

  def read(socket) do
    {protocol, bytes} = parse_header(socket)

    if protocol == "Ghost" do
      {:ok, data} =
        socket
        |> :gen_tcp.recv(bytes)

      :erlang.binary_to_term(data)
    else
      {:error, :invalid_protocol}
    end
  end

  def read(socket, session_key) do
    {protocol, bytes} = parse_header(socket)

    if protocol == "Ghost" do
      {:ok, data} =
        socket
        |> :gen_tcp.recv(bytes)

      data
      |> decrypt(session_key)
    else
      {:error, :invalid_protocol}
    end
  end

  defp binary_message(type, message) do
    message
    |> Map.merge(%{ type: type })
    |> :erlang.term_to_binary()
  end

  defp message_byte_size(message) do
    message
    |> byte_size()
    |> pad_bytes()
  end

  defp create_param(key, value) when is_number(value) do
    to_param_name(key) <> ":+" <> Integer.to_string(value)
  end

  defp create_param(key, value) when is_bitstring(value) do
    to_param_name(key) <> ":^" <> value
  end

  defp create_param(key, value) when is_list(value) do

  end

  defp to_param_name(key) do
    key
    |> Atom.to_string()
    |> String.upcase()
  end

  defp pad_bytes(bytes) do
    bytes = Integer.to_string(bytes)
    num_zeros = 8 - byte_size(bytes)

    String.duplicate("0", num_zeros) <> bytes
  end

  defp parse_header(socket) do
    {:ok, header} =
      socket
      |> :gen_tcp.recv(15) # Will get "Ghost|00000000|" from socket

    [protocol, bytes, _] = String.split(header, "|")
    {bytes, _} = Integer.parse(bytes)

    {protocol, bytes}
  end

  defp decrypt(data, key) do
    :crypto.block_decrypt(:aes_ecb, key, data) |> :erlang.binary_to_term
  end

end
