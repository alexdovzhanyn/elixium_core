defmodule UltraDark.Blockchain.Block do
  alias UltraDark.Blockchain.Block, as: Block
  defstruct [
    index: nil,
    hash: nil,
    previous_hash: nil,
    difficulty: nil,
    nonce: 0,
    timestamp: nil,
    transactions: []
  ]

  @doc """
    When the first node on the UltraDark network spins up, there won't be any blocks in the chain.
    In order to create a base from which all nodes can agree, we create a block called a genesis block.
    This block has the data structure that a block would have, but has hard-coded values. This block
    never needs to be verified by nodes, as it doesn't contain any actual data. The block mined after the
    genesis block must reference the hash of the genesis block as its previous_hash to be valid
  """
  def initialize do
    %Block{
      index: 0,
      hash: "79644A8F062F1BA9F7A32AF2242C04711A634D42F0628ADA6B985B3D21296EEA",
      difficulty: 6.0,
      timestamp: DateTime.utc_now |> DateTime.to_string,
      transactions: [
        %{
          inputs: [],
          outputs: "GENESIS BLOCK"
        }
      ]
    }
  end

  @doc """
    Takes the previous block as an argument
  """
  def initialize(%{index: index, hash: previous_hash}) do
    %Block{
      index: index + 1,
      previous_hash: previous_hash,
      difficulty: 6.0,
      timestamp: DateTime.utc_now |> DateTime.to_string
    }
  end

  @doc """
    The process of mining consists of hashing the index of the block, the hash of the previous block (thus linking the current and previous block),
    the timestamp at which the block was generated, the merkle root of the transactions within the block, and a random nonce. We then check
    to see whether the number represented by the hash is lower than the mining difficulty. If the value of the hash is lower, it is a valid block,
    and we can broadcast the block to other nodes on the network.
  """
  def mine(block) do
    %{index: index, hash: hash, previous_hash: previous_hash, timestamp: timestamp, nonce: nonce} = block

    # I would love to show some sort of hashrate here, but it looks like getting the time with Elixir is incredibly computationally expensive,
    # to the point where mining performance gets HALVED
    IO.write "Block Index: #{index} -- Hash: #{hash} -- Nonce: #{nonce}\r"

    block = %{ block | hash: calculate_hash([Integer.to_string(index), previous_hash,  timestamp, Integer.to_string(nonce)]) }

    if hash_beat_target?(block) do
      block
    else
      mine(%{block | nonce: block.nonce + 1})
    end
  end

  def calculate_hash(header) do
    :crypto.hash(:sha256, header) |> Base.encode16
  end

  @doc """
    Because the hash is a Base16 string, and not an integer, we must first convert the hash to an integer, and afterwards compare it to the target
  """
  def hash_beat_target?(%{hash: hash, difficulty: difficulty}) do
    { integer_value_of_hash, "" } = Integer.parse(hash, 16)
    integer_value_of_hash < calculate_target(difficulty)
  end

  @doc """
    The target is a number based off of the block difficulty. The higher the block difficulty, the lower the target. When a block is being mined,
    the goal is to find a hash that is lower in numerical value than the target. The maximum target (when the difficulty is 0) is
    115792089237316195423570985008687907853269984665640564039457584007913129639935, which means any hash is valid.
  """
  def calculate_target(difficulty) do
    (:math.pow(16, 64 - difficulty) |> round) - 1
  end

  def calculate_block_reward(block_index) do
    100 / :math.pow(2, Integer.floor_div(block_index, 200000))
  end
end
