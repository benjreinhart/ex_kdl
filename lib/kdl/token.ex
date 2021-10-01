defmodule Kdl.Token do
  @type t :: {:eof} | {atom(), non_neg_integer()} | {atom(), non_neg_integer(), any()}

  defguard is_type(token, type) when elem(token, 0) == type

  @type valueless_token_types ::
          :bom
          | :semicolon
          | :left_brace
          | :right_brace
          | :left_paren
          | :right_paren
          | :equals
          | :null
          | :continuation
          | :node_comment
          | :line_comment
          | :multiline_comment

  @type token_types ::
          :boolean
          | :number
          | :string
          | :bare_identifier
          | :newline
          | :whitespace

  @spec new(:eof) :: {:eof}
  def new(:eof) do
    {:eof}
  end

  @spec new(valueless_token_types(), non_neg_integer) :: t
  def new(type, ln) do
    {type, ln}
  end

  @spec new(token_types, non_neg_integer, any) :: t
  def new(type, ln, value) do
    {type, ln, value}
  end

  @spec value(t) :: any
  def value({_type, _ln, value}) do
    value
  end

  def value(_token) do
    nil
  end
end
