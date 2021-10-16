defmodule ExKdl.Chars do
  @moduledoc false

  @bom_char 0xFEFF

  # Newline characters.
  #
  #     https://github.com/kdl-org/kdl/blob/1.0.0/SPEC.md#newline
  #
  @newline_chars [
    0x000A,
    0x000D,
    0x000C,
    0x0085,
    0x2028,
    0x2029
  ]

  @spec newline_chars :: [non_neg_integer]
  def newline_chars() do
    @newline_chars
  end

  # Whitespace characters.
  #
  #     https://github.com/kdl-org/kdl/blob/1.0.0/SPEC.md#whitespace
  #
  @whitespace_chars [
    0x0009,
    0x0020,
    0x00A0,
    0x1680,
    0x2000,
    0x2001,
    0x2002,
    0x2003,
    0x2004,
    0x2005,
    0x2006,
    0x2007,
    0x2008,
    0x2009,
    0x200A,
    0x202F,
    0x205F,
    0x3000
  ]

  @spec whitespace_chars :: [non_neg_integer]
  def whitespace_chars() do
    @whitespace_chars
  end

  # Non-identifier characters.
  #
  #     https://github.com/kdl-org/kdl/blob/16269d432590d440ce07c0623772c89eb302f2c2/SPEC.md#non-identifier-characters
  #
  @non_identifier_chars '"(),/;<=>[\\]{}' ++
                          @whitespace_chars ++
                          @newline_chars ++
                          [@bom_char]

  @spec non_identifier_chars :: [non_neg_integer]
  def non_identifier_chars() do
    @non_identifier_chars
  end

  @min_valid_identifier_char 0x000021
  @max_valid_identifier_char 0x10FFFF

  @valid_identifier_range Range.new(@min_valid_identifier_char, @max_valid_identifier_char)

  @spec min_valid_identifier_char :: 0x000021
  def min_valid_identifier_char(), do: @min_valid_identifier_char

  @spec max_valid_identifier_char :: 0x10FFFF
  def max_valid_identifier_char(), do: @max_valid_identifier_char

  # Escape characters.
  #
  #    https://github.com/kdl-org/kdl/blob/1.0.0/SPEC.md#string
  #
  @escape_char_map %{
    ?\b => "\\b",
    ?\t => "\\t",
    ?\n => "\\n",
    ?\f => "\\f",
    ?\r => "\\r",
    ?" => "\\\"",
    ?\\ => "\\"
  }

  @spec escape_char_map :: %{non_neg_integer => binary}
  def escape_char_map() do
    @escape_char_map
  end

  @max_unicode_codepoint 0x1FFFFF

  @max_1_byte_char 0x007F
  @max_2_byte_char 0x07FF
  @max_3_byte_char 0xFFFF

  @spec max_1_byte_char :: 0x007F
  def max_1_byte_char(), do: @max_1_byte_char

  @spec max_2_byte_char :: 0x07FF
  def max_2_byte_char(), do: @max_2_byte_char

  @spec max_3_byte_char :: 0xFFFF
  def max_3_byte_char(), do: @max_3_byte_char

  @spec get_char_byte_length(non_neg_integer) :: 1 | 2 | 3 | 4
  def get_char_byte_length(char) when char not in 0..@max_unicode_codepoint do
    raise "invalid numeric unicode value"
  end

  def get_char_byte_length(char) when char <= @max_1_byte_char, do: 1
  def get_char_byte_length(char) when char <= @max_2_byte_char, do: 2
  def get_char_byte_length(char) when char <= @max_3_byte_char, do: 3
  def get_char_byte_length(_char), do: 4

  defguard is_bom_char(char)
           when char === @bom_char

  defguard is_whitespace_char(char)
           when char in @whitespace_chars

  # Note that CRLF (\r\n) should be treated as a single newline character
  # and will therefore need to be explicitly handled aside from this guard.
  defguard is_newline_char(char)
           when char in @newline_chars

  defguard is_identifier_char(char)
           when char in @valid_identifier_range and char not in @non_identifier_chars

  defguard is_sign_char(char)
           when char in '+-'

  defguard is_exp_char(char)
           when char in 'eE'

  defguard is_binary_char(char)
           when char in '01'

  defguard is_octal_char(char)
           when char in '01234567'

  defguard is_decimal_char(char)
           when char in '0123456789'

  defguard is_hexadecimal_char(char)
           when char in '0123456789abcdefABCDEF'

  defguard is_initial_identifier_char(char)
           when not is_decimal_char(char) and is_identifier_char(char)
end
