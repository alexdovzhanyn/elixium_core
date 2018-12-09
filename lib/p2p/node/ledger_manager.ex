defmodule Elixium.Node.LedgerManager do
  alias Elixium.Store.Ledger
  alias Elixium.Validator
  alias Elixium.Block
  alias Elixium.Pool.Orphan
  alias Elixium.Store.Oracle
  require Logger

  @moduledoc """
    Handles high level decision logic for forking, saving, and relaying blocks.
  """

  @doc """
    Decide what to do when we've received a new block. All block persistence
    logic is handled internally; this returns an atom describing what the peer
    handler should do with this block.
  """
  @spec handle_new_block(Block) :: :ok | :gossip | :ignore | :invalid | {:missing_blocks, list}
  def handle_new_block(block) do
    # Check if we've already received a block at this index. If we have,
    # diff it against the one we've stored. If we haven't, check to see
    # if this index is the next index in the chain. In the case that its
    # not, we've likely found a new longest chain, so we need to evaluate
    # whether or not we want to switch to that chain
    case Ledger.block_at_height(block.index) do
      :none ->
        last_block = Ledger.last_block()
        block_index = :binary.decode_unsigned(block.index)

        # Will only match if the block we received is building directly
        # on the block that we have as the last block in our chain
        if block_index == 0 || (last_block != :err && block_index == :binary.decode_unsigned(last_block.index) + 1 && block.previous_hash == last_block.hash) do
          # If this block is positioned as the next block in the chain,
          # validate it as such
          validate_new_block(block)
        else
          # Otherwise, check if it's a fork and whether we need to swap to
          # a fork chain
          evaluate_chain_swap(block)
        end

      stored_block -> handle_possible_fork(block, stored_block)
    end
  end

  # Checks whether a block is valid as the next block in the chain. If it is,
  # adds the block to the chain.
  @spec validate_new_block(Block) :: :ok | :invalid
  defp validate_new_block(block) do
    # Recalculate target difficulty if necessary
    difficulty = Block.calculate_difficulty(block)

    case Validator.is_block_valid?(block, difficulty) do
      :ok ->
        # Save the block to our chain since its valid
        Ledger.append_block(block)
        Oracle.inquire(:"Elixir.Elixium.Store.UtxoOracle", {:update_with_transactions, [block.transactions]})
        :ok
      _err -> :invalid
    end
  end

  # Checks whether a given block is a valid fork of an existing block. Doesn't
  # modify the chain, only updates the orphan block pool and decides whether
  # the peer should gossip about this block.
  @spec handle_possible_fork(Block, Block) :: :gossip | :ignore
  defp handle_possible_fork(block, existing_block) do
    case Block.diff_header(existing_block, block) do
      [] ->
        # There is no difference between these blocks. We'll ignore this newly
        # recieved block.
        :ignore
      _diff ->
        block_index = :binary.decode_unsigned(block.index)

        have_orphan? =
          block_index
          |> Orphan.blocks_at_height()
          |> Enum.any?(& &1 == block)

        if have_orphan? do
          :ignore
        else
          # TODO: Should this look at previous_hash as well?
          if Ledger.last_block().index == block.index do
            # This block is a fork of the current latest block in the pool. Add it
            # to our orphan pool and tell the peer to gossip the block.
            Logger.warn("Received fork of current block.")

            Orphan.add(block)
            :gossip
          else
            if block_index == 0 do
              Orphan.add(block)
              :gossip
            else
              # Check the orphan pool for blocks at the previous height whose hash this
              # orphan block references as a previous_hash
              check_orphan_pool_for_ancestors(block)
            end
          end
        end
    end
  end

  # Checks the orphan pool for blocks with a common previous index or previous_hash
  @spec check_orphan_pool_for_ancestors(Block) :: :gossip | :ignore
  defp check_orphan_pool_for_ancestors(block) do
    case Orphan.blocks_at_height(:binary.decode_unsigned(block.index) - 1) do
      [] ->
        # We don't know of any ORPHAN blocks that this block might be referencing.
        # Perhaps this is a fork of a block that we've accepted as canonical
        # into our chain?
        case Ledger.retrieve_block(block.previous_hash) do
          :not_found ->
            # If this block doesn't reference and blocks that we know of, we can not
            # build a chain using this block -- we can't validate this block at all.
            # Our only option is to drop the block. Realistically we shouldn't ever
            # get into this situation unless a malicious actor has sent us a fake block.
            Logger.warn("Received orphan block with no reference to a known block. Dropping orphan")
            :ignore
          _canonical_block ->
            # This block is a fork of a canonical block.
            Logger.warn("Fork of canonical block received")
            Orphan.add(block)
            :gossip
        end

      _orphan_blocks ->
        # This block might be a fork of a block that we have stored in our
        # orphan pool.

        # TODO: Expand this logic. Right now we're adding this block to the
        # orphan pool irrespective of whether or not it has an ancestor in the
        # pool. We should check before we add.
        Logger.warn("Possibly extension of existing fork")
        Orphan.add(block)
        :gossip
    end
  end

  # Try to rebuild a fork chain based on this block and it's ancestors in the
  # orphan pool. If we're successful, validate and try to swap to the new chain.
  # Otherwise, just ignore this block.
  @spec evaluate_chain_swap(Block) :: :ok | :ignore | {:missing_blocks, list}
  defp evaluate_chain_swap(block) do
    # Rebuild the chain backwards until reaching a point where we agree on the
    # same blocks as the fork does.
    case rebuild_fork_chain(block) do
      {:missing_blocks, fork_chain} ->
        # We don't have anything that this block can reference as a previous
        # block, let's save the block as an orphan and see if we can request
        # some more blocks.
        Orphan.add(block)
        {:missing_blocks, fork_chain}
      {fork_chain, fork_source} ->
        current_utxos_in_pool = Oracle.inquire(:"Elixir.Elixium.Store.UtxoOracle", {:retrieve_all_utxos, []})

        # Blocks which need to be reversed. (Everything from the block after
        # the fork source to the current block)
        blocks_to_reverse =
          fork_source.index
          |> :binary.decode_unsigned()
          |> Kernel.+(1)
          |> Range.new(:binary.decode_unsigned(Ledger.last_block().index))
          |> Enum.map(&Ledger.block_at_height/1)
          |> Enum.filter(& &1 != :none)

        # Find transaction inputs that need to be reversed
        # TODO: We're looping over blocks_to_reverse twice here (once to parse
        # inputs and once for outputs). We can likely do this in the same loop.
        all_canonical_transaction_inputs_since_fork =
          Enum.flat_map(blocks_to_reverse, &parse_transaction_inputs/1)

        canon_output_txoids =
          blocks_to_reverse
          |> Enum.flat_map(&parse_transaction_outputs/1)
          |> Enum.map(& &1.txoid)

        # Pool at the time of fork is basically just current pool plus all inputs
        # used in canon chain since fork, minus all outputs created in after fork
        # (this will also remove inputs that were created as outputs and used in
        # the fork)
        pool =
          current_utxos_in_pool ++ all_canonical_transaction_inputs_since_fork
          |> Enum.filter(&(!Enum.member?(canon_output_txoids, &1.txoid)))

        # Traverse the fork chain, making sure each block is valid within its own
        # context.
        {_, final_contextual_pool, _fork_chain, validation_results} =
          fork_chain
          |> Enum.scan({fork_source, pool, fork_chain, []}, &validate_in_context/2)
          |> List.last()

        # Ensure that every block passed validation
        if Enum.all?(validation_results, & &1) do
          Logger.info("Candidate fork chain valid. Switching.")

          # Add everything in final_contextual_pool that is not also in current_utxos_in_pool
          Enum.each(final_contextual_pool -- current_utxos_in_pool, & Oracle.inquire(:"Elixir.Elixium.Store.UtxoOracle", {:add_utxo, [&1]}))

          # Remove everything in current_utxos_in_pool that is not also in final_contextual_pool
          current_utxos_in_pool -- final_contextual_pool
          |> Enum.map(& &1.txoid)
          |> Enum.each(& Oracle.inquire(:"Elixir.Elixium.Store.UtxoOracle", {:remove_utxo, [&1]}))

          # Drop canon chain blocks from the ledger, add them to the orphan pool
          # in case the chain gets revived by another miner
          Enum.each(blocks_to_reverse, fn blk ->
            Orphan.add(blk)
            Ledger.drop_block(blk)
          end)

          # Remove fork chain from orphan pool; now it becomes the canon chain,
          # so we add its blocks to the ledger
          Enum.each(fork_chain, fn blk ->
            Ledger.append_block(blk)
            Orphan.remove(blk)
          end)

          :ok
        else
          :ignore
        end

      _ -> :ignore
    end
  end

  # Recursively loops through the orphan pool to build a fork chain as long as
  # we can, based on a given block.
  @spec rebuild_fork_chain(list) :: {list, Block} | {:missing_blocks, list}
  defp rebuild_fork_chain(chain) when is_list(chain) do
    case Orphan.blocks_at_height(:binary.decode_unsigned(hd(chain).index) - 1) do
      [] ->
        # If index is 0, we've forked back to the genesis block. Let's start
        # validating
        if :binary.decode_unsigned(hd(chain).index) == 0 do
          {chain, hd(chain)}
        else
          Logger.warn("Tried rebuilding fork chain, but was unable to find an ancestor.")
          {:missing_blocks, chain}
        end
      orphan_blocks ->
        orphan_blocks
        |> Enum.filter(& &1.hash == hd(chain).previous_hash)
        |> Enum.find_value(fn candidate_orphan ->
          # Check if we agree on a previous_hash
          case Ledger.retrieve_block(candidate_orphan.previous_hash) do
            # We need to dig deeper...
            :not_found -> rebuild_fork_chain([candidate_orphan | chain])
            # We found the source of this fork. Return the chain we've accumulated
            fork_source -> {[candidate_orphan | chain], fork_source}
          end
        end)
    end
  end

  defp rebuild_fork_chain(block), do: rebuild_fork_chain([block])

  # Return a list of all transaction inputs for every transaction in this block
  @spec parse_transaction_inputs(Block) :: list
  defp parse_transaction_inputs(block), do: Enum.flat_map(block.transactions, &(&1.inputs))

  @spec parse_transaction_outputs(Block) :: list
  defp parse_transaction_outputs(block), do: Enum.flat_map(block.transactions, &(&1.outputs))

  # Validates a given block in the context of the values passed in. This function
  # is primarily meant to be used as an accumulator for Enum.scan. The provided
  # pool will be used as the utxo pool, the provided chain will be used as a
  # faux canonical chain. Results is an array of blocks that have been previously
  # validated using this function.
  @spec validate_in_context(Block, {Block, list, list, list}) :: {Block, list, list, list}
  defp validate_in_context(block, {last, pool, chain, results}) do
    retargeting_window = Application.get_env(:elixium_core, :retargeting_window)

    curr_index_in_fork = Enum.find_index(chain, &(&1 == block))

    blocks_from_canon =
      if curr_index_in_fork < retargeting_window do
        to_get = retargeting_window - curr_index_in_fork

        Ledger.last_n_blocks(to_get, :binary.decode_unsigned(hd(chain).index) - 1)
      else
        []
      end

    get_from_fork = retargeting_window - length(blocks_from_canon)

    chain_without_extra_blocks =
      if curr_index_in_fork > retargeting_window do
        chain -- Enum.take(chain, curr_index_in_fork - retargeting_window)
      else
        chain
      end

    blocks_from_fork = Enum.take(chain_without_extra_blocks, get_from_fork)

    difficulty = Block.calculate_difficulty(block, blocks_from_canon ++ blocks_from_fork)

    valid =
      if :binary.decode_unsigned(block.index) == 0 do
        :ok == Validator.is_block_valid?(block, difficulty)
      else
        :ok == Validator.is_block_valid?(block, difficulty, last, &(pool_check(pool, &1)))
      end

    # Update the contextual utxo pool by removing spent inputs and adding
    # unspent outputs from this block. The following block will use the updated
    # contextual pool for utxo validation
    updated_pool =
      if valid do
        # Get a list of this blocks inputs (now that we've deemed it valid)
        block_input_txoids =
          block
          |> parse_transaction_inputs()
          |> Enum.map(& &1.txoid)

        # Get a list of the outputs this block produced
        block_outputs = parse_transaction_outputs(block)

        # Remove all the outputs that were both created and used within this same
        # block
        Enum.filter(pool ++ block_outputs, &(!Enum.member?(block_input_txoids, &1.txoid)))
      else
        pool
      end

    {block, updated_pool, chain, [valid | results]}
  end

  # Function that gets passed to Validator.is_block_valid?/3, telling it how to
  # evaluate the pool. We're doing this because by default, the validator uses
  # the canonical UTXO pool for validation, but when we're processing a potential
  # fork, we won't have the same exact UTXO pool, so we reconstruct one based on
  # the fork chain. We then use this pool to verify the existence of a particular
  # UTXO in the fork chain.
  @spec pool_check(list, map) :: true | false
  defp pool_check(pool, utxo) do
    case Enum.find(pool, false, & &1.txoid == utxo.txoid) do
      false -> false
      txo_in_pool -> utxo.amount == txo_in_pool.amount && utxo.addr == txo_in_pool.addr
    end
  end

end
