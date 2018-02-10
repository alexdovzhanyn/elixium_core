defmodule UltraDark.Contract do
  alias UltraDark.Ledger
  require Execjs
  @moduledoc """
    Parse, compile, and run javascript
  """

  @doc """
    Call a method defined in the javascript source
  """
  def call(method, binary, opts \\ []) do
    :erlang.binary_to_term(binary)
    |> Execjs.call(method, opts)
  end

  @doc """
    Given a contract address, call a method within that contract
  """
  def run_contract(contract_address, method, opts \\ []) do
    [block_hash, transaction_id] =
      contract_address
      |> (fn address ->
        {:ok, val} = Base.decode16(address)
        val
      end).()
      |> String.split(":")

    transaction =
      Ledger.retrieve_block(block_hash).transactions
      |> Enum.find(&(&1.id == transaction_id))

    call(method, transaction.data, opts)
  end

  @doc """
    Compile a javascript source file to binary (to be used by Execjs later)
  """
  def compile(path) do
    {:ok, script} = File.read(path)

    script_bin =
      Execjs.compile(script)
      |> :erlang.term_to_binary

    binary_path(path)
    |> File.write(script_bin)
  end

  def binary_path(path) do
    String.replace(path, ".js", ".bin")
  end
end
