defmodule KeyPairTest do
  alias Elixium.KeyPair

  use ExUnit.Case, async: true

  test "Can create a keypair and return correct format private and public keys" do
    {pub, priv} = KeyPair.create_keypair()

    assert is_binary(pub)
    assert is_binary(priv)
  end

  test "Mnemonic Is generated and returns correct private key" do
    {public, private} = KeyPair.create_keypair
    mnemonic = KeyPair.create_mnemonic(private)
    {pub_from_mne, priv_from_mne} = KeyPair.gen_keypair(mnemonic)

    assert private == priv_from_mne
  end

  test "Key pair is generated and the private key is able to generate the correct pub key" do
    {public, private} = KeyPair.create_keypair
    {pub_from_mne, priv_from_mne} = KeyPair.gen_keypair(private)

    assert public == pub_from_mne
  end

  test "Can create a signature in the correct format" do
    {_, priv} = KeyPair.create_keypair()
    signature = KeyPair.sign(priv, "this is a string of arbitrary data")

    assert is_binary(signature)
  end

  test "Can verify a signature is correct" do
    {pub, priv} = KeyPair.create_keypair()
    data = "Some data"
    signature = KeyPair.sign(priv, data)

    assert KeyPair.verify_signature(pub, signature, data) == true
  end

  test "Can generate a public address from generated keypair" do
    {pub, _priv} = KeyPair.create_keypair()
    address = KeyPair.address_from_pubkey(pub)
    <<version::bytes-size(3), _rest::binary>> = address

    assert version == "EX0"
    assert pub == KeyPair.address_to_pubkey(address)
  end
end
