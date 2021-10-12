defmodule ExKdl.Parser.Utils do
  alias ExKdl.Token

  @type tokens_type :: list(Token.t())
  @type match_result :: :nomatch | {:match, tokens_type, any}
  @type production_type :: (list(Token.t()) -> match_result)

  @spec one(tokens_type, production_type) :: match_result
  def one(tokens, production) do
    production.(tokens)
  end

  @spec one(any, any, keyword) :: match_result
  def one(tokens, production, alternatives) do
    match_or(tokens, [production | Keyword.get_values(alternatives, :or)])
  end

  @spec zero_or_one(tokens_type, production_type) :: match_result
  def zero_or_one(tokens, production) do
    case production.(tokens) do
      {:match, _tokens, _value} = match ->
        match

      _nomatch ->
        {:match, tokens, nil}
    end
  end

  @spec zero_or_more(tokens_type, production_type) :: match_result
  def zero_or_more(tokens, production) do
    zero_or_more(tokens, production, [])
  end

  defp zero_or_more(tokens, production, matches) do
    case production.(tokens) do
      {:match, tokens, value} ->
        zero_or_more(tokens, production, [value | matches])

      _nomatch ->
        {:match, tokens, Enum.reverse(matches)}
    end
  end

  @spec one_or_more(tokens_type, production_type) :: match_result
  def one_or_more(tokens, production) do
    case zero_or_more(tokens, production) do
      {:match, _tokens, []} ->
        :nomatch

      result ->
        result
    end
  end

  @spec discard_while(tokens_type, (Token.t() -> boolean)) :: tokens_type
  def discard_while(tokens, test_fn) do
    Enum.drop_while(tokens, test_fn)
  end

  defp match_or(tokens, [matcher | matchers]) do
    case matcher.(tokens) do
      {:match, _tokens, _value} = match ->
        match

      _nomatch ->
        match_or(tokens, matchers)
    end
  end

  defp match_or(_tokens, []) do
    :nomatch
  end
end
