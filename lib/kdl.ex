defmodule Kdl do
  alias Kdl.Lexer
  alias Kdl.Parser

  @spec decode(binary()) :: {:ok, list(map())} | {:error, any()}

  def decode(encoded) when is_binary(encoded) do
    with {:ok, tokens} <- Lexer.lex(encoded) do
      Parser.parse(tokens)
    end
  end

  def decode(_) do
    {:error, "Argument to decode/1 must be a kdl-encoded binary"}
  end
end
