defmodule Elixium.HostAvailability.Supervisor do
  use Supervisor

  @moduledoc """
    Starts HostAvailability and HostCheck
  """

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    children = [
      Elixium.HostAvailability,
      Elixium.HostCheck
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
