defmodule UltraDark.GammaCalculator do
  @moduledoc """
    Find gamma costs for various computations
  """

  def gamma_for_computation(%ESTree.BinaryExpression{operator: operator}), do: compute_gamma_for_operator(operator)
  def gamma_for_computation(%ESTree.UpdateExpression{operator: operator}), do: compute_gamma_for_operator(operator)
  def gamma_for_computation(%ESTree.ExpressionStatement{expression: expression}), do: gamma_for_computation(expression)
  def gamma_for_computation(%ESTree.ReturnStatement{argument: argument}), do: gamma_for_computation(argument)
  def gamma_for_computation(%ESTree.VariableDeclaration{declarations: declarations}), do: gamma_for_computation(declarations)
  def gamma_for_computation(%ESTree.VariableDeclarator{init: %{value: value}}), do: calculate_gamma_for_declaration(value)
  # def gamma_for_computation(%ESTree.AssignmentExpression{ left: left }), do: IEx.pry
  def gamma_for_computation(%ESTree.CallExpression{}), do: 0
  def gamma_for_computation([first | rest]), do: gamma_for_computation(rest, [gamma_for_computation(first)])
  def gamma_for_computation([first | rest], gamma_list), do: gamma_for_computation(rest, [gamma_for_computation(first) | gamma_list])
  def gamma_for_computation([], gamma_list), do: Enum.reduce(gamma_list, fn gamma, acc -> acc + gamma end)
  def gamma_for_computation(other) do
    IO.warn("Gamma for computation not implemented for: #{other.type}")
    # IEx.pry
    0
  end

  @spec gamma_for_state_change(map) :: number
  def gamma_for_state_change(new_state) do
    new_state
    |> state_values_list()
    |> Enum.reduce(0, & &2 + calculate_gamma_for_declaration(&1))
  end

  defp state_values_list(state) when is_map(state) do
    state
    |> Map.values()
    |> state_values_list([])
    |> List.flatten()
  end
  defp state_values_list([value | rest], values), do: state_values_list(rest, [state_values_list(value) | values])
  defp state_values_list([], values), do: values
  defp state_values_list(other), do: other

  # Takes in a variable declaration and returns the gamma necessary to store the data
  # within the contract. The cost is mapped to 2500 gamma per byte
  @spec calculate_gamma_for_declaration(any) :: number
  defp calculate_gamma_for_declaration(value) do
    # Is there a cleaner way to calculate the memory size of any var?
    (value |> :erlang.term_to_binary() |> byte_size) * 2500
  end

  # Gamma costs are broken out into the following sets, with each item in @base costing
  # 2 gamma, each in @low costing 3, @medium costing 5 and @medium_high costing 6
  @base [:^, :==, :!=, :===, :!==, :<=, :<, :>, :>=, :instanceof, :|, :&, :"<<", :">>", :>>>, :in]
  @low [:+, :-]
  @medium [:*, :/, :%]
  @medium_high [:++, :--]

  # Takes in a binary tree expression and returns the amount of gamma necessary
  # in order to perform the expression.
  @spec compute_gamma_for_operator(atom) :: number | {:error, tuple}
  defp compute_gamma_for_operator(operator) when operator in @base, do: 2
  defp compute_gamma_for_operator(operator) when operator in @low, do: 3
  defp compute_gamma_for_operator(operator) when operator in @medium, do: 5
  defp compute_gamma_for_operator(operator) when operator in @medium_high, do: 6
  defp compute_gamma_for_operator(operator), do: {:error, {:no_compute_or_update_expression_gamma, operator}}
end
