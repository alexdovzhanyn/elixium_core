defmodule Elixium.Store.BlockCache do

  #Here we jsut want to initialize the table
  def init() do
    table = :ets.new(:block_cache, [:named_table])
  end
  #Wrapped Insertion for the table
  def store(store, block) do
    validate_operation(:ets.insert(store, {block}))
  end
  #Wrapped Delete for the table
  def delete(store, block) do
    validate_operation(:ets.delete(store, {block}))
  end

  #Here we're just checking if the block given i.e the previoius block (the one being behind) is actually behind with the correct index
  def check_block(store, block_2, block_1) do
    with [block_forward] <- :ets.lookup(store, block_2) do
      with {:up, block_2} <- check_index(block_2, block_1) do
        {:up, block_2, block_1}
      end
    end
  end
  #We know were looking for a matching partner in the table so -1 in this case
  defp check_index(block_2, block_1) do
    correct_index = block_2.index - 1
    if block_1.index == correct_index do
      {:up, block_2}
    else
      {:error, "Block Out of Sync"}
    end
  end
  #Now that the blocks have been verified and processed lets remove them from the table
  def remove_blocks(store, {type, message, block_2, block_1}) do
    with :ok <- delete(store, block_2),
          :ok <- delete(store, block_1)do
    :ok
    end
  end

  #this is where we can patch into the validator functions, then return the result
  def check_validation_of_blocks({:up, block_forward, block_back}), do: {:ok, "Validated Forwards", block_forward, block_back}
  def check_validation_of_blocks({:down, block_forward, block_back}), do: {:ok, "Validated Backwards", block_forward, block_back}

  #simple Helper function to validate the operations
  defp validate_operation(ops) do
   case ops do
     true ->
       :ok
     false ->
       :error
     end
  end



end
