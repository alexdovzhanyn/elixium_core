defmodule UltraDark.Blockchain.Block do

  @doc """
    When the first node on the UltraDark network spins up, there won't be any blocks in the chain.
    In order to create a base from which all nodes can agree, we create a block called a genesis block.
    This block has the data structure that a block would have, but has hard-coded values. This block
    never needs to be verified by nodes, as it doesn't contain any actual data. The block mined after the
    genesis block must reference the hash of the genesis block as its previous_hash to be valid
  """
  def initialize do
    %{
      index: 0,
      hash: "79644A8F062F1BA9F7A32AF2242C04711A634D42F0628ADA6B985B3D21296EEA",
      previous_hash: nil,
      nonce: nil,
      difficulty: 5.0,
      timestamp: nil,
      transactions: [
        %{
          inputs: [],
          outputs: "GENESIS BLOCK"
        }
      ]
    }
  end

  def initialize(%{index: index, hash: previous_hash}) do
    %{
      index: index + 1,
      previous_hash: previous_hash,
      nonce: 0,
      difficulty: 5.0,
      timestamp: DateTime.utc_now |> DateTime.to_string,
      transactions: [%{ inputs: [], outputs: [] }]
    }
  end

  @doc """
    The process of mining consists of hashing the index of the block, the hash of the previous block (thus linking the current and previous block),
    the timestamp at which the block was generated, the merkle root of the transactions within the block, and a random nonce. We then check
    to see whether the number represented by the hash is lower than the mining difficulty. If the value of the hash is lower, it is a valid block,
    and we can broadcast the block to other nodes on the network.
  """
  def mine(block) do
    IO.puts "Mining!"
    %{index: index, previous_hash: previous_hash, timestamp: timestamp, nonce: nonce} = block

    blockheader = Integer.to_string(index) <> previous_hash <> timestamp <> Integer.to_string(nonce)

    Map.merge(block, %{
      hash: :crypto.hash(:sha256, blockheader) |> Base.encode16
    })
  end

end
