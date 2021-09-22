defmodule Kdl.Lexer do
  alias Kdl.Token

  # Whitespace characters.
  #
  #     https://github.com/kdl-org/kdl/blob/1.0.0/SPEC.md#whitespace
  #
  defguardp is_whitespace(char)
            when char in [
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
                   0x3000,
                   # BOM considered whitespace:
                   0xFEFF
                 ]

  # Newline characters.
  #
  # Note that CRLF (\r\n) should be treated as a single newline character
  # and will therefore need to be explicitly handled separately from this guard.
  #
  #     https://github.com/kdl-org/kdl/blob/1.0.0/SPEC.md#newline
  #
  defguardp is_newline(char) when char in [0x000A, 0x000D, 0x000C, 0x0085, 0x2028, 0x2029]

  # Non-identifier characters.
  #
  #     https://github.com/kdl-org/kdl/blob/16269d432590d440ce07c0623772c89eb302f2c2/SPEC.md#non-identifier-characters
  #
  defguardp is_non_identifier_char(char)
            when char in [
                   # "
                   0x22,
                   # (
                   0x28,
                   # )
                   0x29,
                   # ,
                   0x2C,
                   # /
                   0x2F,
                   # ;
                   0x3B,
                   # <
                   0x3C,
                   # =
                   0x3D,
                   # >
                   0x3E,
                   # [
                   0x5B,
                   # \
                   0x5C,
                   # ]
                   0x5D,
                   # {
                   0x7B,
                   # }
                   0x7D
                 ] or
                   char < 0x21 or
                   char > 0x10FFFF or
                   is_whitespace(char) or
                   is_newline(char)

  defguardp is_identifier_char(char) when not is_non_identifier_char(char)

  defguardp is_initial_identifier_char(char) when char not in ?0..?9 and is_identifier_char(char)

  defguardp is_sign_char(char) when char in '+-'

  defguardp is_exp_char(char) when char in 'eE'

  defguardp is_digit(char) when char in ?0..?9

  defguardp is_binary_digit(char) when char in ?0..?1

  defguardp is_octal_digit(char) when char in ?0..?7

  defguardp is_hexadecimal_digit(char) when is_digit(char) or char in ?a..?f or char in ?A..?F

  @spec lex(binary()) :: {:ok, list(Token.t())} | {:error, binary()}

  def lex(encoded) when is_binary(encoded) do
    lex(encoded, 1, [])
  end

  defp lex("", _ln, tks) do
    [%Token.Eof{} | tks]
    |> Enum.reverse()
    |> then(&{:ok, &1})
  end

  defp lex(<<"\r\n", src::binary>>, ln, tks) do
    token = %Token.Newline{value: "\r\n"}
    lex(src, ln + 1, [token | tks])
  end

  defp lex(<<c::utf8, src::binary>>, ln, tks) when is_newline(c) do
    token = %Token.Newline{value: <<c::utf8>>}
    lex(src, ln + 1, [token | tks])
  end

  defp lex(<<c::utf8, src::binary>>, ln, tks) when is_whitespace(c) do
    token = %Token.Whitespace{value: <<c::utf8>>}
    lex(src, ln, [token | tks])
  end

  defp lex(<<";", src::binary>>, ln, tks) do
    token = %Token.Semicolon{}
    lex(src, ln, [token | tks])
  end

  defp lex(<<"{", src::binary>>, ln, tks) do
    token = %Token.LeftBrace{}
    lex(src, ln, [token | tks])
  end

  defp lex(<<"}", src::binary>>, ln, tks) do
    token = %Token.RightBrace{}
    lex(src, ln, [token | tks])
  end

  defp lex(<<"(", src::binary>>, ln, tks) do
    token = %Token.LeftParen{}
    lex(src, ln, [token | tks])
  end

  defp lex(<<")", src::binary>>, ln, tks) do
    token = %Token.RightParen{}
    lex(src, ln, [token | tks])
  end

  defp lex(<<"=", src::binary>>, ln, tks) do
    token = %Token.Equals{}
    lex(src, ln, [token | tks])
  end

  defp lex(<<"/*", _::binary>> = src, ln, tks) do
    case lex_multiline_comment(src, 0, []) do
      {:ok, {comment, src}} ->
        token = %Token.MultilineComment{value: comment}
        lex(src, ln, [token | tks])

      {:error, message} ->
        {:error, "[line #{ln}] #{message}"}
    end
  end

  defp lex(<<"//", src::binary>>, ln, tks) do
    {comment, src} = take_until_newline(src, ["//"])
    token = %Token.LineComment{value: comment}
    lex(src, ln, [token | tks])
  end

  defp lex(<<"\\", src::binary>>, ln, tks) do
    token = %Token.Continuation{}
    lex(src, ln, [token | tks])
  end

  defp lex(<<"/-", src::binary>>, ln, tks) do
    token = %Token.NodeComment{}
    lex(src, ln, [token | tks])
  end

  defp lex(<<c::utf8, _::binary>> = src, ln, tks) when is_digit(c) do
    case lex_number(src, []) do
      {:ok, {token, src}} ->
        lex(src, ln, [token | tks])

      {:error, message} ->
        {:error, "[line #{ln}] #{message}"}
    end
  end

  defp lex(<<c1::utf8, c2::utf8, _::binary>> = src, ln, tks)
       when is_sign_char(c1) and is_digit(c2) do
    <<_::utf8, src::binary>> = src

    case lex_number(src, [c1]) do
      {:ok, {token, src}} ->
        lex(src, ln, [token | tks])

      {:error, message} ->
        {:error, "[line #{ln}] #{message}"}
    end
  end

  defp lex(<<"\""::utf8, src::binary>>, ln, tks) do
    case lex_string(src, []) do
      {:ok, {str, src}} ->
        token = %Token.String{value: str}
        lex(src, ln, [token | tks])

      {:error, message} ->
        {:error, "[line #{ln}] #{message}"}
    end
  end

  defp lex(<<"r", c::utf8, _::binary>> = src, ln, tks) when c in '#"' do
    <<_::utf8, rest::binary>> = src

    case count_contiguous_number_signs(rest, 0) do
      {count, <<"\"", src::binary>>} ->
        case lex_raw_string(src, count, []) do
          {:ok, {str, src}} ->
            token = %Token.RawString{value: str}
            lex(src, ln, [token | tks])

          {:error, message} ->
            {:error, "[line #{ln}] #{message}"}
        end

      _ ->
        # If we're here, it means this was not the start of a raw string, but
        # instead an identifier ('r' and '#' are valid bare identifier characters).
        lex_identifier(src, ln, tks)
    end
  end

  defp lex(<<c::utf8, _::binary>> = src, ln, tks) when is_initial_identifier_char(c) do
    lex_identifier(src, ln, tks)
  end

  defp lex(src, ln, _tks) do
    {:error, "[line #{ln}] unrecognized character '#{String.first(src)}'"}
  end

  defp lex_identifier(src, ln, tks) do
    {token, src} =
      case lex_identifier(src, []) do
        {"null", src} ->
          {%Token.Null{}, src}

        {"true", src} ->
          {%Token.Boolean{value: true}, src}

        {"false", src} ->
          {%Token.Boolean{value: false}, src}

        {identifier, src} ->
          {%Token.BareIdentifier{value: identifier}, src}
      end

    lex(src, ln, [token | tks])
  end

  defp lex_identifier("" = src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp lex_identifier(<<c::utf8, _::binary>> = src, iodata) when is_non_identifier_char(c) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp lex_identifier(<<c::utf8, src::binary>>, iodata) do
    lex_identifier(src, [iodata | [<<c::utf8>>]])
  end

  defp lex_number("" = src, iodata) do
    {:ok, IO.iodata_to_binary(iodata), src}
  end

  defp lex_number(<<"0b", src::binary>>, iodata) do
    case src do
      # The first character following 0b must be between 0-1
      <<c::utf8, _::binary>> when is_binary_digit(c) ->
        {number_str, src} = parse_binary(src, [iodata | ["0b"]])
        {:ok, {%Token.BinaryNumber{value: number_str}, src}}

      _ ->
        {:error, "invalid number literal"}
    end
  end

  defp lex_number(<<"0o", src::binary>>, iodata) do
    case src do
      # The first character following 0o must be between 0-7
      <<c::utf8, _::binary>> when is_octal_digit(c) ->
        {number_str, src} = parse_octal(src, [iodata | ["0o"]])
        {:ok, {%Token.OctalNumber{value: number_str}, src}}

      _ ->
        {:error, "invalid number literal"}
    end
  end

  defp lex_number(<<"0x", src::binary>>, iodata) do
    case src do
      # The first character following 0x must be between 0-9 or a-z or A-Z
      <<c::utf8, _::binary>> when is_hexadecimal_digit(c) ->
        {number_str, src} = parse_hexadecimal(src, [iodata | ["0x"]])
        {:ok, {%Token.HexadecimalNumber{value: number_str}, src}}

      _ ->
        {:error, "invalid number literal"}
    end
  end

  defp lex_number(<<c::utf8, _::binary>> = src, iodata) when is_digit(c) do
    case parse_decimal_number(src, iodata, false, false) do
      {:ok, {number_str, src}} ->
        {:ok, {%Token.DecimalNumber{value: number_str}, src}}

      error ->
        error
    end
  end

  defp lex_string("", _iodata) do
    {:error, "unterminated string meets end of file"}
  end

  defp lex_string(<<"\"", src::binary>>, iodata) do
    {:ok, {IO.iodata_to_binary(iodata), src}}
  end

  defp lex_string(<<"\\n", src::binary>>, iodata) do
    lex_string(src, [iodata | [?\n]])
  end

  defp lex_string(<<"\\r", src::binary>>, iodata) do
    lex_string(src, [iodata | [?\r]])
  end

  defp lex_string(<<"\\t", src::binary>>, iodata) do
    lex_string(src, [iodata | [?\t]])
  end

  defp lex_string(<<"\\\\", src::binary>>, iodata) do
    lex_string(src, [iodata | [?\\]])
  end

  defp lex_string(<<"\\/", src::binary>>, iodata) do
    lex_string(src, [iodata | [?/]])
  end

  defp lex_string(<<"\\\"", src::binary>>, iodata) do
    lex_string(src, [iodata | [?"]])
  end

  defp lex_string(<<"\\b", src::binary>>, iodata) do
    lex_string(src, [iodata | [?\b]])
  end

  defp lex_string(<<"\\f", src::binary>>, iodata) do
    lex_string(src, [iodata | [?\f]])
  end

  defp lex_string(<<"\\u{", src::binary>>, iodata) do
    case parse_unicode_escape(src, 0, []) do
      {:ok, {codepoint, src}} ->
        lex_string(src, [iodata | [<<codepoint::utf8>>]])

      error ->
        error
    end
  end

  defp lex_string(<<"\\", _src::binary>>, _iodata) do
    {:error, "invalid escape in string"}
  end

  defp lex_string(<<c::utf8, src::binary>>, iodata) do
    lex_string(src, [iodata | [<<c::utf8>>]])
  end

  defp lex_raw_string("", _number_sign_count, _iodata) do
    {:error, "unterminated string meets end of file"}
  end

  defp lex_raw_string(<<"\"", src::binary>>, 0, iodata) do
    {:ok, {IO.iodata_to_binary(iodata), src}}
  end

  defp lex_raw_string(<<"\"#", src::binary>>, 1, iodata) do
    {:ok, {IO.iodata_to_binary(iodata), src}}
  end

  defp lex_raw_string(<<"\"#", src::binary>>, number_sign_count, iodata)
       when number_sign_count > 1 do
    expected_count = number_sign_count - 1

    case count_contiguous_number_signs(src, 0) do
      {^expected_count, src} ->
        {:ok, {IO.iodata_to_binary(iodata), src}}

      _ ->
        lex_raw_string(src, number_sign_count, [iodata | [?", ?#]])
    end
  end

  defp lex_raw_string(<<c::utf8, src::binary>>, number_sign_count, iodata) do
    lex_raw_string(src, number_sign_count, [iodata | [<<c::utf8>>]])
  end

  defp lex_multiline_comment("", count, _iodata) when count > 0 do
    {:error, "unterminated multiline comment"}
  end

  defp lex_multiline_comment(<<"*/", src::binary>>, 1, iodata) do
    {:ok, {IO.iodata_to_binary([iodata | ["*/"]]), src}}
  end

  defp lex_multiline_comment(<<"*/", src::binary>>, count, iodata) when count > 1 do
    lex_multiline_comment(src, count - 1, [iodata | ["*/"]])
  end

  defp lex_multiline_comment(<<"/*", src::binary>>, count, iodata) do
    lex_multiline_comment(src, count + 1, [iodata | ["/*"]])
  end

  defp lex_multiline_comment(<<c::utf8, src::binary>>, count, iodata) do
    lex_multiline_comment(src, count, [iodata | [<<c::utf8>>]])
  end

  defp parse_binary("" = src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp parse_binary(<<c::utf8, src::binary>>, iodata) when is_binary_digit(c) or c == ?_ do
    parse_binary(src, [iodata | [c]])
  end

  defp parse_binary(src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp parse_octal("" = src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp parse_octal(<<c::utf8, src::binary>>, iodata) when is_octal_digit(c) or c == ?_ do
    parse_octal(src, [iodata | [c]])
  end

  defp parse_octal(src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp parse_hexadecimal("" = src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp parse_hexadecimal(<<c::utf8, src::binary>>, iodata)
       when is_hexadecimal_digit(c) or c == ?_ do
    parse_hexadecimal(src, [iodata | [c]])
  end

  defp parse_hexadecimal(src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp parse_decimal_number("" = src, iodata, _dot, _exp) do
    {:ok, {IO.iodata_to_binary(iodata), src}}
  end

  defp parse_decimal_number(<<c::utf8, src::binary>>, iodata, dot, exp)
       when is_digit(c) or c == ?_ do
    parse_decimal_number(src, [iodata | [c]], dot, exp)
  end

  # This matches when we have already seen a "." in the number. For example:
  #
  #     10.01.1
  #          ^
  # Since 10.01 is a valid number literal and .[digit] is a valid identifier,
  # this isn't an error in the lexer. Therefore, we return the number parsed
  # up until the second "." (10.01) as our valid number literal.
  defp parse_decimal_number(<<".", _::binary>> = src, iodata, true, _exp) do
    {:ok, {IO.iodata_to_binary(iodata), src}}
  end

  # This matches when a character other than a digit (0-9) immediately follows
  # the ".". For example:
  #
  #     10._ or 10.a
  #        ^       ^
  # In this case, 10. is the start of a valid number literal, but it must have
  # at least one digit after the "." to be valid. Since that isn't the case here,
  # we return an error indicating the syntax is invalid.
  defp parse_decimal_number(<<".", c::utf8, _::binary>>, _iodata, false, _exp)
       when not is_digit(c) do
    {:error, "invalid number literal"}
  end

  # At this point, we know that we:
  #
  #     1. Haven't already seen a "." in this number literal
  #     2. We know that the character after the "." is a digit
  #        (we handled the case where it isn't above)
  #
  # So, as long we are not in the exponent part of a number literal,
  # this is a valid placement of a "." inside a number literal.
  defp parse_decimal_number(<<".", src::binary>>, iodata, false, false) do
    parse_decimal_number(src, [iodata | ["."]], true, false)
  end

  # This matches when we have already seen an exponent in the number. For example:
  #
  #     2e10ear
  #         ^
  # Since 2e10 is a valid number literal and "e" is the start of a valid identifier,
  # this isn't an error in the lexer. Therefore, we return the number parsed up until
  # the second e (2e10) as our valid number literal.
  defp parse_decimal_number(<<c::utf8, _::binary>> = src, iodata, _dot, true)
       when is_exp_char(c) do
    {:ok, {IO.iodata_to_binary(iodata), src}}
  end

  # This matches when we have not already encountered an exponent in the number
  # and we see an "e" (or "E") followed by a digit. For example:
  #
  #     2e2
  #      ^^
  # This is the start of a valid exponent part of a number literal and so we
  # continue parsing.
  defp parse_decimal_number(<<c1::utf8, c2::utf8, src::binary>>, iodata, dot, false)
       when is_exp_char(c1) and is_digit(c2) do
    parse_decimal_number(src, [iodata | [c1, c2]], dot, true)
  end

  # This matches when we have not already encountered an exponent in the number
  # and we see an "e" (or "E") followed by a sign (+-) and then followed by a digit.
  # For example:
  #
  #     2e-2
  #      ^^^
  # This is the start of a valid exponent part of a number literal and so we
  # continue parsing.
  defp parse_decimal_number(<<c1::utf8, c2::utf8, c3::utf8, src::binary>>, iodata, dot, false)
       when is_exp_char(c1) and is_sign_char(c2) and is_digit(c3) do
    parse_decimal_number(src, [iodata | [c1, c2, c3]], dot, true)
  end

  # This matches when we have not already encountered an exponent in the number
  # and we see an "e" (or "E") followed by some character that is not a sign or
  # a digit.
  #
  #     2e_2
  #      ^^
  # This is an invalid number literal and so we return an error indicating the
  # syntax is malformed.
  defp parse_decimal_number(<<c::utf8, _::binary>>, _iodata, _dot, false) when is_exp_char(c) do
    {:error, "invalid number literal"}
  end

  defp parse_decimal_number(src, iodata, _dot, _exp) do
    {:ok, {IO.iodata_to_binary(iodata), src}}
  end

  defp parse_unicode_escape("", _length, _iodata) do
    {:error, "unterminated string meets end of file"}
  end

  defp parse_unicode_escape(<<"\"", _::binary>>, _length, _iodata) do
    {:error, "unterminated unicode escape"}
  end

  defp parse_unicode_escape(<<c::utf8, _::binary>>, length, _iodata)
       when length == 0 and c == ?} do
    {:error, "unicode escape must have at least 1 hex digit"}
  end

  defp parse_unicode_escape(<<c::utf8, _::binary>>, length, _iodata)
       when length > 6 and c != ?} do
    {:error, "unicode escape cannot be more than 6 hex digits"}
  end

  defp parse_unicode_escape(<<c::utf8, src::binary>>, length, iodata)
       when length <= 6 and c == ?} do
    case iodata |> IO.iodata_to_binary() |> String.to_integer(16) do
      codepoint when codepoint in 0..0x10FFFF ->
        {:ok, {codepoint, src}}

      _ ->
        {:error, "unicode escape must be at most 10FFFF"}
    end
  end

  defp parse_unicode_escape(<<c::utf8, src::binary>>, length, iodata)
       when is_hexadecimal_digit(c) do
    parse_unicode_escape(src, length + 1, [iodata | [c]])
  end

  defp parse_unicode_escape(_src, _length, _iodata) do
    {:error, "invalid character in unicode escape"}
  end

  defp count_contiguous_number_signs(<<"#", src::binary>>, count) do
    count_contiguous_number_signs(src, count + 1)
  end

  defp count_contiguous_number_signs(src, count) do
    {count, src}
  end

  defp take_until_newline("" = src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp take_until_newline(<<c::utf8, _::binary>> = src, iodata) when is_newline(c) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp take_until_newline(<<c::utf8, src::binary>>, iodata) do
    take_until_newline(src, [iodata | [<<c::utf8>>]])
  end
end
