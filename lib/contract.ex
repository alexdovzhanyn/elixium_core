defmodule UltraDark.Contract do
  alias UltraDark.{Ledger, AST, Utilities}

  @moduledoc """
    Parse, compile, and run javascript
  """

  @doc """
    Call a method defined in the javascript source
  """
  @spec call_method(String.t(), binary, List) :: any
  def call_method(binary, method, opts \\ []) do
    {class_name, source} = :erlang.binary_to_term(binary)

    class_name
    |> generate_javascript_contract_snippet(method, opts)
    |> run_in_context(source)
  end

  @doc """
    Create a javascript snipped that initializes the class defined within a contract
    and call a given method on it. This also returns the gamma cost expended while
    running the computation.
  """
  @spec generate_javascript_contract_snippet(String.t(), {String.t(), list}, map) :: String.t()
  defp generate_javascript_contract_snippet(class, {method, opts}, parameters) do
    opts = Poison.encode!(opts, encode: :javascript)
    constructor_args = generate_contract_parameters(parameters)
    max_gamma = parameters.max_gamma

    "
      UltraDark.charge_gamma = UltraDark.charge_gamma(#{max_gamma})
      let contractInstance = new #{class}(#{constructor_args});

      try {
        let comp = contractInstance.sanitized_#{method}.apply(contractInstance, #{opts})
        return [comp, gamma];
      } catch (e) {
        return e
      }
    "
  end

  @doc """
    Takes a binary javascript file, and adds a given script to the end of the file, then runs it
    E.G. run_in_context("return new MyContract().main()", bin)
  """
  @spec run_in_context(String.t(), binary) :: any
  defp run_in_context(script, source) do
    context =
      source
      |> prepare_executable
      |> Execjs.compile()

    Execjs.exec(context.(script))
  end

  @doc """
    Given a contract address, call a method within that contract
  """
  @spec run_contract(String.t(), String.t(), List) :: any
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
  @spec compile(String.t()) :: binary
  def compile(path) do
    {:ok, src} = File.read(path)

    context =
      src
      |> AST.generate_from_source()
      |> AST.sanitize_computation()
      |> AST.remap_with_gamma()

    contract_name =
      context.body
      |> Enum.find(fn item ->
         case item do
           %ESTree.ClassDeclaration{superClass: %ESTree.MemberExpression{object: %ESTree.Identifier{name: "UltraDark"}}} -> true
           _ -> false
         end
        end)
      |> (fn class -> class.id.name end).()

    script = ESTree.Tools.Generator.generate(context)

    :erlang.term_to_binary({contract_name, script})
  end

  @doc """
    Combine the source file with the contents of our contract js file, which specifies
    the structure for contracts
  """
  @spec prepare_executable(String.t()) :: String.t()
  def prepare_executable(source) do
    {:ok, ultradarkjs} = File.read("lib/contracts/Contract.js")
    ultradarkjs <> source
  end

  @spec generate_contract_parameters(map) :: String.t()
  defp generate_contract_parameters(%{block_hash: block_hash, block_index: block_index, block_nonce: block_nonce, transaction_id: transaction_id}) do
    "{
      block_hash: '#{block_hash}',
      block_index: #{block_index},
      block_nonce: #{block_nonce},
      transaction_id: '#{transaction_id}'
    }"
  end

  @doc """
    Deterministically generate a contract address. This uses the public key of the person
    creating the contract, plus the binary code for the contract itself. It is possible to have
    multiple contracts with the same contract address generated if the creator deploys
    the same contract multiple times. This is fine though, since they're the same transaction
    they'll have the same contents, so we can just get the first instance we find when
    looking up based on the contract address.
  """
  @spec generate_contract_address(String.t(), binary) :: String.t()
  def generate_contract_address(pubkey, contract) do
    Utilities.sha3_base16([pubkey, contract])
  end
end
