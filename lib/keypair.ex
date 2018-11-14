defmodule Elixium.KeyPair do
  alias Elixium.Utilities
  use Bitwise
  require Integer

  @algorithm :ecdh
  @sigtype :ecdsa
  @curve :secp256k1
  @hashtype :sha256

  @moduledoc """
    All the functions responsible for creating keypairs and using them to sign
    data / verify signatures
  """

  @doc """
    Creates a new keypair and stores the private key in a keyfile. Returns the
    public and private key
  """
  @spec create_keypair :: {binary, binary}
  def create_keypair do
    keypair = :crypto.generate_key(@algorithm, @curve)
    create_keyfile(keypair)

    keypair
  end

  @doc """
    Reads in a private key from the given file, and returns a tuple with the
    public and private key
  """
  @spec get_from_file(String.t()) :: {binary, binary}
  def get_from_file(path) do
    {:ok, private} = File.read(path)
    :crypto.generate_key(@algorithm, @curve, private)
  end

  @spec create_keyfile(tuple) :: :ok | {:error, any}
  defp create_keyfile({public, private}) do
    if !File.dir?(".keys"), do: File.mkdir(".keys")

    address = address_from_pubkey(public)

    File.write(".keys/#{address}.key", private)
  end

  @spec sign(binary, String.t()) :: String.t()
  def sign(private_key, data) do
    :crypto.sign(@sigtype, @hashtype, data, [private_key, @curve])
  end

  @spec verify_signature(binary, binary, String.t()) :: boolean
  def verify_signature(public_key, signature, data) do
    :crypto.verify(@sigtype, @hashtype, data, signature, [public_key, @curve])
  end

  def checksum(version, compressed_pubkey) do
    <<check::bytes-size(4), _::bits>> = :crypto.hash(:sha256, version <> compressed_pubkey)

    check
  end

  def address_from_pubkey(pubkey) do
    version = Application.get_env(:elixium_core, :address_version)
    compressed_pubkey = compress_pubkey(pubkey)

    addr =
      compressed_pubkey <> checksum(version, compressed_pubkey)
      |> Base58.encode()

    version <> addr
  end

  def compress_pubkey(<<4, x::bytes-size(32), y::bytes-size(32)>>) do
    y_even =
      y
      |> :binary.decode_unsigned()
      |> Integer.is_even()

    prefix = if y_even, do: <<2>>, else: <<3>>

    prefix <> x
  end

  def address_to_pubkey(address) do
    version = Application.get_env(:elixium_core, :address_version)

    <<key_version::bytes-size(3)>> <> addr = address
    <<prefix::bytes-size(1), x::bytes-size(32), checksum::binary>> = Base58.decode(addr)

    y = calculate_y_from_x(x, prefix)

    <<4>> <> x <> y
  end

  # Adapted from stackoverflow answer
  # https://stackoverflow.com/questions/43629265/deriving-an-ecdsa-uncompressed-public-key-from-a-compressed-one/43654055
  defp calculate_y_from_x(x, prefix) do
    p =
      "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F"
      |> Base.decode16!()
      |> :binary.decode_unsigned()

    y_square_root =
      x
      |> :crypto.mod_pow(3, p)
      |> :binary.decode_unsigned()
      |> Kernel.+(7)
      |> mod(p)
      |> :crypto.mod_pow(Integer.floor_div(p + 1, 4), p)
      |> :binary.decode_unsigned

    y =
      if (prefix == <<2>> && (y_square_root &&& 1) != 0) || (prefix == <<3>> && ((y_square_root &&& 1) == 0)) do
        mod(-y_square_root, p)
      else
        y_square_root
      end

    :binary.encode_unsigned(y)
  end

  # Erlang rem/2 is not the same as modulus. This is true modulus
  defp mod(x, y) when x > 0, do: rem(x, y)
  defp mod(x, y) when x < 0, do: rem(x + y, y)
  defp mod(0, _y), do: 0
end
