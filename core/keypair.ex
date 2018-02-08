defmodule UltraDark.KeyPair do
  @algorithm :ecdh
  @sigtype :ecdsa
  @curve :secp256k1
  @hashtype :sha256

  @doc """
    Creates a new keypair and stores the private key in a keyfile. Returns the public and private key
  """
  @spec create_keypair :: {binary, binary}
  def create_keypair do
    keypair = :crypto.generate_key(@algorithm, @curve)
    keypair |> create_keyfile

    keypair
  end

  @doc """
    Reads in a private key from the given file, and returns a tuple with the public and private key
  """
  @spec get_from_file(String.t) :: {binary, binary}
  def get_from_file(path) do
    {:ok, private} = File.read(path)

    private
    |> (fn pkey -> :crypto.generate_key(@algorithm, @curve, pkey) end).()
  end

  @spec create_keyfile(tuple) :: :ok | {:error, any}
  defp create_keyfile({public, private}) do
    if (!File.dir? ".keys"), do: File.mkdir ".keys"

    pub_hex = public |> Base.encode16
    File.write(".keys/#{pub_hex}.key", private)
  end

  @spec sign(String.t, String.t) :: {:ok, binary} | {:error, any}
  def sign(public_key, data) do
    keypath = ".keys/#{public_key}.key"
    if (!File.exists? keypath), do: {:error, :key_doesnt_exist}

    {_, private_key} = get_from_file(keypath)

    {:ok, :crypto.sign(@sigtype, @hashtype, data, [private_key, @curve])}
  end

  @spec verify_signature(binary, binary, String.t) :: boolean
  def verify_signature(public_key, signature, data) do
    :crypto.verify(@sigtype, @hashtype, data, signature, [public_key, @curve])
  end
end
