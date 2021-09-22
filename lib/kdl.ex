defmodule Kdl do
  alias Kdl.Parser

  @spec decode(binary()) :: {:ok | :error, term()}

  def decode(encoded) when is_binary(encoded) do
    Parser.parse(encoded)
  end

  def decode(_) do
    {:error, "Argument to decode/1 must be a kdl-encoded binary"}
  end
end
