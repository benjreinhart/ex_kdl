defmodule Kdl do
  alias Kdl.Encoder
  alias Kdl.Lexer
  alias Kdl.Parser

  @spec decode(binary()) :: {:ok, list(map())} | {:error, any()}

  def decode(encoded) when is_binary(encoded) do
    with {:ok, tokens} <- Lexer.lex(encoded) do
      Parser.parse(tokens)
    end
  end

  def decode(_) do
    {:error, "Argument to decode/1 must be a KDL-encoded binary"}
  end

  def encode(nodes) when is_list(nodes) do
    Encoder.encode(nodes)
  end

  def encode(_) do
    {:error, "Argument to encode/1 must be a list of KDL nodes"}
  end
end
