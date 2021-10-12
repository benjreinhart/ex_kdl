defmodule ExKdl.Utils.Number do
  @type format :: :decimal | :binary | :octal | :hexadecimal

  @spec parse!(binary, format) :: Decimal.t()
  def parse!(str, :decimal) do
    Decimal.new(str)
  end

  def parse!(str, :hexadecimal) do
    str
    |> String.to_integer(16)
    |> Decimal.new()
  end

  def parse!(str, :binary) do
    str
    |> String.to_integer(2)
    |> Decimal.new()
  end

  def parse!(str, :octal) do
    str
    |> String.to_integer(8)
    |> Decimal.new()
  end
end
