defmodule UtilitiesTest do
  alias UltraDark.Utilities
  use ExUnit.Case, async: true

  test "can calculate merkle root of a list with odd amount of items" do
    list = ["hash1", "hash2", "hash3"]
    assert Utilities.calculate_merkle_root(list) == "37748952D20C83B32F3D55E85021C8383AFB377E4A6ABDBAEA2C9D5C4C54A216"
  end

  test "can calculate merkle root of a list with even amount of items" do
    list = ["hash1", "hash2", "hash3", "hash4"]
    assert Utilities.calculate_merkle_root(list) == "0518CB5545932CCCF2301E9DB1ABD33392B4E740CCE6D9CCD3494B05DBB47A72"
  end

  test "can calculate merkle root of a list with just 1 item" do
    list = ["hash1"]
    assert Utilities.calculate_merkle_root(list) == "AF316ECB91A8EE7AE99210702B2D4758F30CDDE3BF61E3D8E787D74681F90A6E"
  end

  test "can create base 16 representation of sha3 of input" do
    assert Utilities.sha3_base16("some data") == "5933E9273166934A6EBAAF58171074479309A7DE84607C450B01C265B3081712"
    assert Utilities.sha3_base16("some data") == Utilities.sha3_base16(["some data"])
  end
end
