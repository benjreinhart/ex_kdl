defmodule Kdl.Chars do
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

  # Non-identifier characters.
  #
  #     https://github.com/kdl-org/kdl/blob/16269d432590d440ce07c0623772c89eb302f2c2/SPEC.md#non-identifier-characters
  #
  @non_identifier_chars '"(),/;<=>[\\]{}' ++
                          @whitespace_chars ++
                          @newline_chars ++
                          [@bom_char]

  defguard is_bom_char(char)
           when char === @bom_char

  defguard is_whitespace_char(char)
           when char in @whitespace_chars

  # Note that CRLF (\r\n) should be treated as a single newline character
  # and will therefore need to be explicitly handled aside from this guard.
  defguard is_newline_char(char)
           when char in @newline_chars

  defguard is_identifier_char(char)
           when char in 0x21..0x10FFFF and char not in @non_identifier_chars

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
