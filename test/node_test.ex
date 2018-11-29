defmodule NodeTest do
  alias Elixium.Node.Supervisor

  use ExUnit.Case, async: true
  @peer_list Supervisor.fetch_peers_from_registry(31013)

  test "Initial fetch of Peer Returns Populated List" do
    peer_list = @peer_list

    assert Enum.empty?(peer_list) == false
  end

  test "Initial fetch of Peer Registry filters own local & public ip" do
    peer_list = @peer_list

    has_own_public? =
      peer_list
      |> Enum.member?(Supervisor.fetch_public_ip["ip"])

    has_own_private? =
      peer_list
      |> Enum.member?(Supervisor.fetch_local_ip)

    assert has_own_private? == false
    assert has_own_public? == false
  end

end
