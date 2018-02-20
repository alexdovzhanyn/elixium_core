defmodule UltraDark.Contract do
  alias UltraDark.Ledger
  @moduledoc """
    Parse, compile, and run javascript
  """

  @doc """
    Call a method defined in the javascript source
  """
  @spec call_method(String.t, binary, List) :: any
  def call_method(method, binary, opts \\ []) do
    :erlang.binary_to_term(binary)
    |> prepare_executable
    |> Execjs.compile
    |> Execjs.call(method, opts)
  end

  @doc """
    Takes a binary javascript file, and adds a given script to the end of the file, then runs it
    E.G. run_in_context("return new MyContract().main()", bin)
  """
  @spec run_in_context(String.t, binary) :: any
  def run_in_context(script, binary) do
    context =
      binary
      |> :erlang.binary_to_term
      |> prepare_executable
      |> Execjs.compile
    Execjs.exec context.(script)
  end

  @doc """
    Given a contract address, call a method within that contract
  """
  @spec run_contract(String.t, String.t, List) :: any
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

    call_method(method, transaction.data, opts)
  end

  @doc """
    Compile a javascript source file to binary (to be used by Execjs later). The output
    file name will be the same as the input, except with a .bin extension
  """
  def compile(path) do
    {:ok, script} = File.read(path)

    binary_path(path)
    |> File.write(:erlang.term_to_binary(script))
  end

  @doc """
    Combine the source file with the contents of our contract js file, which specifies
    the structure for contracts
  """
  @spec prepare_executable(String.t) :: String.t
  def prepare_executable(source) do
    {:ok, ultradarkjs} = File.read("core/contracts/Contract.js")
    ultradarkjs <> source
  end

  @spec binary_path(String.t) :: String.t
  defp binary_path(path) do
    String.replace(path, ".js", ".bin")
  end

  def test_the_contract do
    {:ok, src} = File.read("test.js")

    context =
      src
      |> UltraDark.AST.generate_from_source
      |> UltraDark.AST.remap_with_gamma
      |> ESTree.Tools.Generator.generate
      |> IO.inspect
      |> UltraDark.Contract.prepare_executable
      |> Execjs.compile

    Execjs.exec context.("let c = new MyContract({block_hash: 'wfwefwfwfwfewwf'}); return [c.main(), gamma];")
  end
end
