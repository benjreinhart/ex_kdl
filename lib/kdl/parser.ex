defmodule Kdl.Parser do
  alias Kdl.Lexer

  @spec parse(binary()) :: {:ok | :error, term()}

  def parse(encoded) when is_binary(encoded) do
    case Lexer.lex(encoded) do
      {:ok, tokens} -> do_parse(tokens)
      error_result -> error_result
    end
  end

  def parse(_) do
    {:error, "Argument to parse/1 must be a kdl-encoded binary"}
  end

  defp do_parse(tokens) do
    tokens
  end
end
