defmodule Kdl.Number do
  @type format :: :integer | :float | :binary | :octal | :hexadecimal

  @spec parse(binary, format) :: number
  def parse(str, :integer) do
    String.to_integer(str)
  end

  def parse(str, :float) do
    {float, ""} = Float.parse(str)
    float
  end

  def parse(str, :hexadecimal) do
    String.to_integer(str, 16)
  end

  def parse(str, :binary) do
    String.to_integer(str, 2)
  end

  def parse(str, :octal) do
    String.to_integer(str, 8)
  end
end
