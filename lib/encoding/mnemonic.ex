defmodule Elixium.Mnemonic do
  @words :elixium_core
         |> :code.priv_dir()
         |> Path.join("words.txt")
         |> File.stream!()
         |> Stream.map(&String.trim/1)
         |> Enum.to_list()

  @allowed_lengths [128, 160, 192, 224, 256]

  def generate(entropy_length \\ List.last(@allowed_lengths))

  def generate(entropy_length)
      when not (entropy_length in @allowed_lengths),
      do: {:error, "Entropy length must be one of #{inspect(@allowed_lengths)}"}

  def words, do: @words

  def allowed_lengths, do: @allowed_lengths

  def random_bytes(entropy_length) do
    entropy_length
    |> bits_to_bytes()
    |> :crypto.strong_rand_bytes()
  end

  def bits_to_bytes(bits), do: div(bits, 8)

  def checksum_length(entropy_bytes) do
    entropy_bytes
    |> bit_size()
    |> div(32)
  end

  def maybe_normalize(binary) do
    binary
    |> String.valid?()
    |> normalize(binary)
  end

  defp normalize(true, string), do: Base.decode16!(string, case: :mixed)
  defp normalize(false, binary), do: binary
end
