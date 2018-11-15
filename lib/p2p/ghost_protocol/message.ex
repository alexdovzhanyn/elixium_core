defmodule Elixium.P2P.GhostProtocol.Message do
  alias Elixium.Utilities
  require Logger

  @moduledoc """
    Create and read messages that are sent over TCP
  """

  @doc """
    Create an unencrypted message that will be passed to a peer, with the
    contents of message_map
  """
  @spec build(String.t(), map) :: String.t()
  def build(type, message_map) do
    message = binary_message(type, message_map)
    bytes = message_byte_size(message)
    version = Application.get_env(:elixium, :ghost_protocol_version)

    ["Ghost", bytes, version, message]
    |> Enum.join("|")
  end

  @doc """
    Same as build/2 except the message is encrypted
  """
  @spec build(String.t(), map, <<_::256>>) :: String.t()
  def build(type, message_map, session_key) when is_map(message_map) do
    version = Application.get_env(:elixium, :ghost_protocol_version)

    message =
      type
      |> binary_message(message_map)
      |> Utilities.pad(32)

    encrypted_message = :crypto.block_encrypt(:aes_ecb, session_key, message)
    bytes = message_byte_size(encrypted_message)

    message =
      ["Ghost", bytes, version, encrypted_message]
      |> Enum.join("|")

    {:ok, message}
  end

  # If the first build/3 doesn't match, it's an invalid message
  def build(_, _, _), do: :error

  @doc """
    Read a full unencrypted message from the socket
  """
  @spec read(reference) :: map | {:error, :invalid_protocol}
  def read(socket) do
    {protocol, bytes, predata} = parse_header(socket)
    need = bytes - byte_size(predata)
    if protocol == "Ghost" do
      {:ok, data} = :gen_tcp.recv(socket, need)

      :erlang.binary_to_term(predata<>data)
    else
      {:error, :invalid_protocol}
    end
  end

  @doc """
    Validate & decrypt a packet. A packet can contain more than one message
  """
  @spec read(binary, <<_::256>>, reference, list) :: List
  def read(data, session_key, socket, messages \\ [])

  def read(<<>>, _session_key, _socket, messages), do: messages

  def read(data, session_key, socket, messages) do
    [protocol, bytes, version | _] = String.split(data, "|")
    header = "Ghost|" <> bytes <> "|" <> version <> "|"

    {bytes_body, _} = Integer.parse(bytes)
    take_bytes = bytes_body + byte_size(header)
    need_bytes = take_bytes - byte_size(data)
    IO.inspect(take_bytes, label: "Message Byte Size")

    # Sometimes we get a packet with incomplete data. Parse use the byte count
    # in the message header to determine how many bytes we're waiting for and
    # await those bytes
    rest_message =
      if need_bytes > 0 do
         Logger.info("Not enough bytes! Waiting for #{need_bytes} more bytes...")
         {:ok, missing_bytes} = :gen_tcp.recv(socket, need_bytes)
         Logger.info("Got the #{need_bytes} bytes! Constructing message")
         missing_bytes
      else
        <<>>
      end

    # Take one full message, the rest will be parsed in the next passthrough
    <<message :: binary-size(take_bytes)>> <> rest = data <> rest_message

    [_, encrypted_message] = String.split(message, header)

    decrypted_message =
      if protocol == "Ghost" do
        decrypt(encrypted_message, session_key)
      else
        {:error, :invalid_protocol}
      end

    read(rest, session_key, socket, [decrypted_message | messages])
  end

  @doc """
    A wrapper function for :gen_tcp.send.
    Should probably update the typespec to be more accurate with
    the return value if theres an error.
  """
  @spec send(binary, reference) :: :ok | any
  def send(message, socket) do
    case :gen_tcp.send(socket, message) do
      :ok -> socket
      err -> err
    end
  end

  # Convert a message body to binary
  @spec binary_message(String.t(), map) :: binary
  defp binary_message(type, message) do
    message
    |> Map.merge(%{type: type})
    |> :erlang.term_to_binary()
  end

  @spec message_byte_size(String.t()) :: integer
  defp message_byte_size(message) do
    message
    |> byte_size()
    |> pad_bytes()
  end

  # Since message byte count must be specified as 8 bytes ("00000000"),
  # pad any integer with the necessary amount of 0's to make the length 8
  @spec pad_bytes(integer) :: String.t()
  defp pad_bytes(bytes) do
    bytes = Integer.to_string(bytes)
    num_zeros = 8 - byte_size(bytes)

    String.duplicate("0", num_zeros) <> bytes
  end

  # Read the head of a message, where the protocol type is specified, followed
  # by the length, in bytes, of the rest of the message
  @spec parse_header(reference) :: {String.t(), integer}
  defp parse_header(socket) do
    {:ok, header} =
      socket
      # Will get "Ghost|00000000|v1.0|" from socket
      |> :gen_tcp.recv(20)

    [protocol, bytes, version, predata] = String.split(header, "|")
    {bytes, _} = Integer.parse(bytes)

    {protocol, bytes, predata}
  end

  @spec decrypt(bitstring, <<_::256>>) :: map
  defp decrypt(data, key) do
    :crypto.block_decrypt(:aes_ecb, key, data) |> :erlang.binary_to_term()
  end
end
