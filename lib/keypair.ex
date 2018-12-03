defmodule Elixium.KeyPair do
  alias Elixium.Mnemonic
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

  @doc """
    Creates a new mnemonic to give to users based off private key
  """
  @spec create_mnemonic(binary) :: String.t()
  def create_mnemonic(private), do: Mnemonic.from_entropy(private)

  @doc """
    Generates a keypair from the seed phrase or from the private key, leading " " will switch to mnemonic to import key from
  """
  @spec gen_keypair(String.t() | binary) :: {binary, binary}
  def gen_keypair(phrase) do
    if String.contains?(phrase, " ") do
        private = Mnemonic.to_entropy(phrase)
        {pub, priv} = get_from_private(private)
        create_keyfile({pub, priv})
      else
        {pub, priv} = get_from_private(phrase)
        create_keyfile({pub, priv})
    end
  end

  @spec sign(binary, String.t()) :: String.t()
  def sign(private_key, data) do
    :crypto.sign(@sigtype, @hashtype, data, [private_key, @curve])
  end

  @spec verify_signature(binary, binary, String.t()) :: boolean
  def verify_signature(public_key, signature, data) do
    :crypto.verify(@sigtype, @hashtype, data, signature, [public_key, @curve])
  end

  @doc """
    Using a public address, fetch the correct keyfile and return the only the private key
  """
  @spec get_priv_from_file(String.t()) :: {binary, binary}
  def get_priv_from_file(pub) do
    unix_address =
      :elixium_core
      |> Application.get_env(:unix_key_address)
      |> Path.expand()

    key_path = "#{unix_address}/#{pub}.key"
    {_, priv} = get_from_file(key_path)
    priv
  end

  @doc """
    Returns a 4 byte checksum of the provided pubkey
  """
  @spec checksum(String.t(), binary) :: binary
  def checksum(version, compressed_pubkey) do
    <<check::bytes-size(4), _::bits>> = :crypto.hash(:sha256, version <> compressed_pubkey)

    check
  end

  @doc """
    Generates a Base58 encoded compressed address based on a public key.
    First 3 bytes of the address are the version number of the address, and last
    4 bytes of the address are the checksum of the public key. This checksum
    allows for address validation, i.e. checking mistyped addresses before creating
    a transaction.
  """
  @spec address_from_pubkey(binary) :: String.t()
  def address_from_pubkey(pubkey) do
    version = Application.get_env(:elixium_core, :address_version)
    compressed_pubkey = compress_pubkey(pubkey)

    addr =
      compressed_pubkey <> checksum(version, compressed_pubkey)
      |> Base58.encode()

    version <> addr
  end

  @doc """
    Compresses an ECDSA public key from 65 bytes to 33 bytes by discarding
    the y coordinate.
  """
  @spec compress_pubkey(binary) :: binary
  def compress_pubkey(<<4, x::bytes-size(32), y::bytes-size(32)>>) do
    y_even =
      y
      |> :binary.decode_unsigned()
      |> Integer.is_even()

    prefix = if y_even, do: <<2>>, else: <<3>>

    prefix <> x
  end

  @doc """
    Returns the uncompressed public key stored within the given address.
  """
  @spec address_to_pubkey(String.t()) :: binary
  def address_to_pubkey(address) do
    <<_key_version::bytes-size(3)>> <> addr = address
    <<prefix::bytes-size(1), x::bytes-size(32), _checksum::binary>> = Base58.decode(addr)

    y = calculate_y_from_x(x, prefix)

    <<4>> <> x <> y
  end

  def get_from_private(private) do
    :crypto.generate_key(@algorithm, @curve, private)
  end

  @spec create_keyfile(tuple) :: :ok | {:error, any}
  defp create_keyfile({public, private}) do
    unix_address =
      :elixium_core
      |> Application.get_env(:unix_key_address)
      |> Path.expand()

    if !File.dir?(unix_address), do: File.mkdir(unix_address)

    address = address_from_pubkey(public)

    File.write!("#{unix_address}/#{address}.key", private)
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
