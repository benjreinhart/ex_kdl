defmodule ExKdl.Lexer do
  alias ExKdl.Token
  alias ExKdl.Errors.SyntaxError
  alias ExKdl.Utils.Number

  import ExKdl.Chars,
    only: [
      is_bom_char: 1,
      is_newline_char: 1,
      is_whitespace_char: 1,
      is_sign_char: 1,
      is_exp_char: 1,
      is_binary_char: 1,
      is_octal_char: 1,
      is_decimal_char: 1,
      is_hexadecimal_char: 1,
      is_identifier_char: 1,
      is_initial_identifier_char: 1
    ]

  @spec lex(binary()) :: {:ok, list(term())} | {:error, term()}

  def lex(encoded) when is_binary(encoded) do
    lex(encoded, 1, [])
  end

  defp lex(<<c::utf8, _::binary>> = src, ln, tks) when is_newline_char(c) do
    {src, char} = get_newline_char(src)
    token = Token.new(:newline, ln, char)
    lex(src, ln + 1, [token | tks])
  end

  defp lex(<<c::utf8, src::binary>>, ln, tks) when is_whitespace_char(c) do
    token = Token.new(:whitespace, ln, <<c::utf8>>)
    lex(src, ln, [token | tks])
  end

  defp lex(<<?;, src::binary>>, ln, tks) do
    token = Token.new(:semicolon, ln)
    lex(src, ln, [token | tks])
  end

  defp lex(<<?{, src::binary>>, ln, tks) do
    token = Token.new(:left_brace, ln)
    lex(src, ln, [token | tks])
  end

  defp lex(<<?}, src::binary>>, ln, tks) do
    token = Token.new(:right_brace, ln)
    lex(src, ln, [token | tks])
  end

  defp lex(<<?(, src::binary>>, ln, tks) do
    token = Token.new(:left_paren, ln)
    lex(src, ln, [token | tks])
  end

  defp lex(<<?), src::binary>>, ln, tks) do
    token = Token.new(:right_paren, ln)
    lex(src, ln, [token | tks])
  end

  defp lex(<<?=, src::binary>>, ln, tks) do
    token = Token.new(:equals, ln)
    lex(src, ln, [token | tks])
  end

  defp lex(<<?/, ?*, _::binary>> = src, ln, tks) do
    line_started_on = ln

    case lex_multiline_comment(src, ln, 0) do
      {:error, message} ->
        {:error, SyntaxError.new(ln, message)}

      {src, ln} ->
        token = Token.new(:multiline_comment, line_started_on)
        lex(src, ln, [token | tks])
    end
  end

  defp lex(<<?/, ?/, src::binary>>, ln, tks) do
    src
    |> advance_until_newline()
    |> lex(ln, [Token.new(:line_comment, ln) | tks])
  end

  defp lex(<<?\\, src::binary>>, ln, tks) do
    token = Token.new(:continuation, ln)
    lex(src, ln, [token | tks])
  end

  defp lex(<<?/, ?-, src::binary>>, ln, tks) do
    token = Token.new(:node_comment, ln)
    lex(src, ln, [token | tks])
  end

  defp lex(<<c::utf8, _::binary>> = src, ln, tks) when is_decimal_char(c) do
    lex_number(src, [], ln, tks)
  end

  defp lex(<<c1::utf8, c2::utf8, _::binary>> = src, ln, tks)
       when is_sign_char(c1) and is_decimal_char(c2) do
    <<_::utf8, src::binary>> = src
    lex_number(src, [c1], ln, tks)
  end

  defp lex(<<?", src::binary>>, ln, tks) do
    line_started_on = ln

    case lex_string(src, ln, []) do
      {src, ln, str} ->
        token = Token.new(:string, line_started_on, str)
        lex(src, ln, [token | tks])

      {:error, message} ->
        {:error, SyntaxError.new(ln, message)}
    end
  end

  defp lex(<<?r, c::utf8, _::binary>> = src, ln, tks) when c in '#"' do
    <<_::utf8, rest::binary>> = src
    line_started_on = ln

    case count_contiguous_number_signs(rest, 0) do
      {<<?", src::binary>>, count} ->
        case lex_raw_string(src, ln, [], count) do
          {src, ln, str} ->
            token = Token.new(:string, line_started_on, str)
            lex(src, ln, [token | tks])

          {:error, message} ->
            {:error, SyntaxError.new(ln, message)}
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

  defp lex(<<>>, _ln, tks) do
    tokens = [Token.new(:eof) | tks]
    {:ok, Enum.reverse(tokens)}
  end

  defp lex(<<c::utf8, src::binary>>, ln, tks) when is_bom_char(c) do
    token = Token.new(:bom, ln)
    lex(src, ln, [token | tks])
  end

  defp lex(src, ln, _tks) do
    {:error, SyntaxError.new(ln, "unrecognized character '#{String.first(src)}'")}
  end

  defp lex_identifier(src, ln, tks) do
    {src, token} =
      case lex_identifier(src, []) do
        {src, "null"} ->
          {src, Token.new(:null, ln)}

        {src, "true"} ->
          {src, Token.new(:boolean, ln, true)}

        {src, "false"} ->
          {src, Token.new(:boolean, ln, false)}

        {src, identifier} ->
          {src, Token.new(:bare_identifier, ln, identifier)}
      end

    lex(src, ln, [token | tks])
  end

  defp lex_identifier(<<c::utf8, _::binary>> = src, iodata) when not is_identifier_char(c) do
    {src, IO.iodata_to_binary(iodata)}
  end

  defp lex_identifier(<<c::utf8, src::binary>>, iodata) do
    lex_identifier(src, [iodata | [<<c::utf8>>]])
  end

  defp lex_identifier(<<>> = src, iodata) do
    {src, IO.iodata_to_binary(iodata)}
  end

  defp lex_number(src, iodata, ln, tks) do
    case lex_number(src, iodata) do
      {:error, message} ->
        {:error, SyntaxError.new(ln, message)}

      {src, number} ->
        token = Token.new(:number, ln, number)
        lex(src, ln, [token | tks])
    end
  end

  defp lex_number(<<?0, ?b, src::binary>>, iodata) do
    case src do
      # The first character following 0b must be between 0-1
      <<c::utf8, _::binary>> when is_binary_char(c) ->
        {number_str, src} = parse_binary(src, iodata)
        {src, Number.parse!(number_str, :binary)}

      _ ->
        {:error, "invalid number literal"}
    end
  end

  defp lex_number(<<?0, ?o, src::binary>>, iodata) do
    case src do
      # The first character following 0o must be between 0-7
      <<c::utf8, _::binary>> when is_octal_char(c) ->
        {number_str, src} = parse_octal(src, iodata)
        {src, Number.parse!(number_str, :octal)}

      _ ->
        {:error, "invalid number literal"}
    end
  end

  defp lex_number(<<?0, ?x, src::binary>>, iodata) do
    case src do
      # The first character following 0x must be between 0-9 or a-z or A-Z
      <<c::utf8, _::binary>> when is_hexadecimal_char(c) ->
        {number_str, src} = parse_hexadecimal(src, iodata)
        {src, Number.parse!(number_str, :hexadecimal)}

      _ ->
        {:error, "invalid number literal"}
    end
  end

  defp lex_number(<<c::utf8, _::binary>> = src, iodata) when is_decimal_char(c) do
    case parse_decimal(src, iodata, false, false) do
      {:ok, {number_str, src}} ->
        {src, Number.parse!(number_str, :decimal)}

      error ->
        error
    end
  end

  defp lex_string(<<?", src::binary>>, ln, iodata) do
    {src, ln, IO.iodata_to_binary(iodata)}
  end

  defp lex_string(<<?\\, c::utf8, src::binary>>, ln, iodata) do
    case c do
      ?" ->
        lex_string(src, ln, [iodata | [?"]])

      ?n ->
        lex_string(src, ln, [iodata | [?\n]])

      ?t ->
        lex_string(src, ln, [iodata | [?\t]])

      ?\\ ->
        lex_string(src, ln, [iodata | [?\\, ?\\]])

      ?/ ->
        lex_string(src, ln, [iodata | [?/]])

      ?u ->
        case src do
          <<"{", src::binary>> ->
            case parse_unicode_escape(src, [], 0) do
              {:error, message} ->
                {:error, message}

              {src, codepoint} ->
                lex_string(src, ln, [iodata | [<<codepoint::utf8>>]])
            end

          _ ->
            {:error, "invalid escape in string"}
        end

      ?r ->
        lex_string(src, ln, [iodata | [?\r]])

      ?b ->
        lex_string(src, ln, [iodata | [?\b]])

      ?f ->
        lex_string(src, ln, [iodata | [?\f]])

      _ ->
        {:error, "invalid escape in string"}
    end
  end

  defp lex_string(<<c::utf8, _::binary>> = src, ln, iodata) when is_newline_char(c) do
    {src, char} = get_newline_char(src)
    lex_string(src, ln + 1, [iodata | [char]])
  end

  defp lex_string(<<c::utf8, src::binary>>, ln, iodata) do
    lex_string(src, ln, [iodata | [<<c::utf8>>]])
  end

  defp lex_string(<<>>, _ln, _iodata) do
    {:error, "unterminated string meets end of file"}
  end

  defp lex_raw_string(<<?", src::binary>>, ln, iodata, number_sign_count) do
    case count_contiguous_number_signs(src, 0) do
      {src, ^number_sign_count} ->
        {src, ln, IO.iodata_to_binary(iodata)}

      _ ->
        lex_raw_string(src, ln, [iodata | [?"]], number_sign_count)
    end
  end

  defp lex_raw_string(<<c::utf8, _::binary>> = src, ln, iodata, number_sign_count)
       when is_newline_char(c) do
    {src, char} = get_newline_char(src)
    lex_raw_string(src, ln + 1, [iodata | [char]], number_sign_count)
  end

  defp lex_raw_string(<<?\\, src::binary>>, ln, iodata, number_sign_count) do
    lex_raw_string(src, ln, [iodata | [?\\, ?\\]], number_sign_count)
  end

  defp lex_raw_string(<<c::utf8, src::binary>>, ln, iodata, number_sign_count) do
    lex_raw_string(src, ln, [iodata | [<<c::utf8>>]], number_sign_count)
  end

  defp lex_raw_string(<<>>, _ln, _iodata, _number_sign_count) do
    {:error, "unterminated string meets end of file"}
  end

  defp lex_multiline_comment(<<?*, ?/, src::binary>>, ln, count) do
    case count do
      1 ->
        {src, ln}

      _ ->
        lex_multiline_comment(src, ln, count - 1)
    end
  end

  defp lex_multiline_comment(<<?/, ?*, src::binary>>, ln, count) do
    lex_multiline_comment(src, ln, count + 1)
  end

  defp lex_multiline_comment(<<c::utf8, _::binary>> = src, ln, count) when is_newline_char(c) do
    {src, _char} = get_newline_char(src)
    lex_multiline_comment(src, ln + 1, count)
  end

  defp lex_multiline_comment(<<_::utf8, src::binary>>, ln, count) do
    lex_multiline_comment(src, ln, count)
  end

  defp lex_multiline_comment(<<>>, _ln, _count) do
    {:error, "unterminated multiline comment"}
  end

  defp parse_binary(<<c::utf8, src::binary>>, iodata) when is_binary_char(c) do
    parse_binary(src, [iodata | [c]])
  end

  defp parse_binary(<<?_, src::binary>>, iodata) do
    parse_binary(src, iodata)
  end

  defp parse_binary(src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp parse_octal(<<c::utf8, src::binary>>, iodata) when is_octal_char(c) do
    parse_octal(src, [iodata | [c]])
  end

  defp parse_octal(<<?_, src::binary>>, iodata) do
    parse_octal(src, iodata)
  end

  defp parse_octal(src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp parse_hexadecimal(<<c::utf8, src::binary>>, iodata) when is_hexadecimal_char(c) do
    parse_hexadecimal(src, [iodata | [c]])
  end

  defp parse_hexadecimal(<<?_, src::binary>>, iodata) do
    parse_hexadecimal(src, iodata)
  end

  defp parse_hexadecimal(src, iodata) do
    {IO.iodata_to_binary(iodata), src}
  end

  defp parse_decimal(<<c::utf8, src::binary>>, iodata, dot, exp) when is_decimal_char(c) do
    parse_decimal(src, [iodata | [c]], dot, exp)
  end

  defp parse_decimal(<<?_, src::binary>>, iodata, dot, exp) do
    parse_decimal(src, iodata, dot, exp)
  end

  # This matches when we have already seen a "." in the number. For example:
  #
  #     10.01.1
  #          ^
  # Since 10.01 is a valid number literal and .[digit] is a valid identifier,
  # this isn't an error in the lexer. Therefore, we return the number parsed
  # up until the second "." (10.01) as our valid number literal.
  defp parse_decimal(<<?., _::binary>> = src, iodata, true, _exp) do
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
  defp parse_decimal(<<?., c::utf8, _::binary>>, _iodata, false, _exp)
       when not is_decimal_char(c) do
    {:error, "invalid number literal"}
  end

  # This matches when a dot is immediately followed by EOF.
  #
  #     10.
  #
  # In this case, the numeric literal is incomplete and is
  # therefore an error.
  defp parse_decimal(<<?.>>, _iodata, _dot, _exp) do
    {:error, "invalid number literal"}
  end

  # At this point, we know that we:
  #
  #     1. Haven't already seen a "." in this number literal
  #     2. We know that the character after the "." is a digit
  #        (we handled the cases where it isn't above)
  #
  # So, as long we are not in the exponent part of a number literal,
  # this is a valid placement of a "." inside a number literal.
  defp parse_decimal(<<?., src::binary>>, iodata, false, false) do
    parse_decimal(src, [iodata | [?.]], true, false)
  end

  # This matches when we have already seen an exponent in the number. For example:
  #
  #     2e10ear
  #         ^
  # Since 2e10 is a valid number literal and "e" is the start of a valid identifier,
  # this isn't an error in the lexer. Therefore, we return the number parsed up until
  # the second e (2e10) as our valid number literal.
  defp parse_decimal(<<c::utf8, _::binary>> = src, iodata, _dot, true) when is_exp_char(c) do
    {:ok, {IO.iodata_to_binary(iodata), src}}
  end

  # This matches when we have not already encountered an exponent in the number
  # and we see an "e" (or "E") followed by a digit. For example:
  #
  #     2e2
  #      ^^
  # This is the start of a valid exponent part of a number literal and so we
  # continue parsing.
  defp parse_decimal(<<c1::utf8, c2::utf8, src::binary>>, iodata, dot, false)
       when is_exp_char(c1) and is_decimal_char(c2) do
    parse_decimal(src, [iodata | [c1, c2]], dot, true)
  end

  # This matches when we have not already encountered an exponent in the number
  # and we see an "e" (or "E") followed by a sign (+-) and then followed by a digit.
  # For example:
  #
  #     2e-2
  #      ^^^
  # This is the start of a valid exponent part of a number literal and so we
  # continue parsing.
  defp parse_decimal(<<c1::utf8, c2::utf8, c3::utf8, src::binary>>, iodata, dot, false)
       when is_exp_char(c1) and is_sign_char(c2) and is_decimal_char(c3) do
    parse_decimal(src, [iodata | [c1, c2, c3]], dot, true)
  end

  # This matches when we have not already encountered an exponent in the number
  # and we see an "e" (or "E") followed by some character that is not a sign or
  # a digit (including EOF).
  #
  #     2e_2
  #      ^^
  # This is an invalid number literal and so we return an error indicating the
  # syntax is malformed.
  defp parse_decimal(<<c::utf8, _::binary>>, _iodata, _dot, false) when is_exp_char(c) do
    {:error, "invalid number literal"}
  end

  defp parse_decimal(src, iodata, _dot, _exp) do
    {:ok, {IO.iodata_to_binary(iodata), src}}
  end

  defp parse_unicode_escape(<<?", _::binary>>, _iodata, _length) do
    {:error, "unterminated unicode escape"}
  end

  defp parse_unicode_escape(<<c::utf8, _::binary>>, _iodata, length)
       when length == 0 and c == ?} do
    {:error, "unicode escape must have at least 1 hex digit"}
  end

  defp parse_unicode_escape(<<c::utf8, _::binary>>, _iodata, length)
       when length > 6 and c != ?} do
    {:error, "unicode escape cannot be more than 6 hex digits"}
  end

  defp parse_unicode_escape(<<c::utf8, src::binary>>, iodata, length)
       when length <= 6 and c == ?} do
    case iodata |> IO.iodata_to_binary() |> String.to_integer(16) do
      codepoint when codepoint in 0..0x10FFFF ->
        {src, codepoint}

      _ ->
        {:error, "unicode escape must be at most 10FFFF"}
    end
  end

  defp parse_unicode_escape(<<c::utf8, src::binary>>, iodata, length)
       when is_hexadecimal_char(c) do
    parse_unicode_escape(src, [iodata | [c]], length + 1)
  end

  defp parse_unicode_escape(<<>>, _iodata, _length) do
    {:error, "unterminated string meets end of file"}
  end

  defp parse_unicode_escape(_src, _length, _iodata) do
    {:error, "invalid character in unicode escape"}
  end

  defp count_contiguous_number_signs(<<?#, src::binary>>, count) do
    count_contiguous_number_signs(src, count + 1)
  end

  defp count_contiguous_number_signs(src, count) do
    {src, count}
  end

  defp advance_until_newline(<<c::utf8, _::binary>> = src) when is_newline_char(c) do
    src
  end

  defp advance_until_newline(<<_::utf8, src::binary>>) do
    advance_until_newline(src)
  end

  defp advance_until_newline(<<>> = src) do
    src
  end

  defp get_newline_char(<<?\n, src::binary>>) do
    {src, <<?\n>>}
  end

  defp get_newline_char(<<?\r, ?\n, src::binary>>) do
    {src, <<?\r, ?\n>>}
  end

  defp get_newline_char(<<c::utf8, src::binary>>) when is_newline_char(c) do
    {src, <<c::utf8>>}
  end
end
