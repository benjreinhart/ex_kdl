defmodule Kdl.Token do
  @type valueless_token_type ::
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

  @type token_type ::
          :boolean
          | :binary_number
          | :octal_number
          | :decimal_number
          | :hexadecimal_number
          | :string
          | :raw_string
          | :bare_identifier
          | :newline
          | :whitespace

  @spec new(:eof) :: :eof
  def new(:eof) do
    :eof
  end

  @spec new(valueless_token_type(), non_neg_integer) ::
          {valueless_token_type(), non_neg_integer}
  def new(type, ln) do
    {type, ln}
  end

  @spec new(token_type, non_neg_integer, any) :: {token_type, non_neg_integer, any}
  def new(type, ln, value) do
    {type, ln, value}
  end
end
