defmodule KeyPairTest do
  alias UltraDark.KeyPair
  use ExUnit.Case, async: true

  setup _ do
    on_exit fn -> File.rm_rf!(".keys") end
    :ok
  end

  test "can create a keypair" do
    {pub, priv} = KeyPair.create_keypair

    assert is_binary(pub)
    assert is_binary(priv)
  end

  test "can create a signature" do
    {_, priv} = KeyPair.create_keypair
    signature = KeyPair.sign(priv, "this is a string of arbitrary data")

    assert is_binary(signature)
  end

  test "can verify a signature" do
    {pub, priv} = KeyPair.create_keypair
    data = "Some data"

    signature = KeyPair.sign(priv, data)

    assert KeyPair.verify_signature(pub, signature, data) == true
  end
end
