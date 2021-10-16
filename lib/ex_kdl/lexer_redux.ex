defmodule ExKdl.LexerRedux do
  @moduledoc false

  alias ExKdl.{Chars, DecodeError, Token}

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

  @spec lex(binary) :: {:ok, [Token.t()]} | {:error, DecodeError.t()}
  def lex(input) when is_binary(input) do
    lex(input, input, 1, 0, [])
  end

  defp lex(<<char::utf8, rest::bits>> = src, input, ln, i, tks) do
    case rest do
      rest when is_whitespace_char(char) ->
        {rest, j} = consume_consecutive_whitespace(rest, i + Chars.get_char_byte_length(char))
        tks = [{:whitespace, ln, i..j} | tks]
        lex(rest, input, ln, j, tks)

      _ when is_newline_char(char) ->
        {rest, updated_ln, j} = consume_consecutive_newlines(src, ln, i)
        tks = [{:newline, ln, i..j} | tks]
        lex(rest, input, updated_ln, j, tks)

      rest when char === ?" ->
        case lex_string(rest, input, ln, i + 1, 0, []) do
          {rest, updated_ln, j, string} ->
            tks = [{:string, ln, i..j, string} | tks]
            lex(rest, input, updated_ln, j, tks)

          {:error, message} ->
            {:error, %DecodeError{message: message, line: ln}}
        end

      <<?", rest::bits>> when char === ?r ->
        case lex_raw_string(rest, input, ln, i + 2, 0, [], 0) do
          {rest, updated_ln, j, string} ->
            tks = [{:string, ln, i..j, string} | tks]
            lex(rest, input, updated_ln, j, tks)

          {:error, message} ->
            {:error, %DecodeError{message: message, line: ln}}
        end

      <<?#, rest::bits>> when char === ?r ->
        case count_contiguous_number_signs(rest, 1) do
          {<<?", rest::bits>>, number_sign_count} ->
            skip = i + 2 + number_sign_count

            case lex_raw_string(rest, input, ln, skip, 0, [], number_sign_count) do
              {rest, updated_ln, j, string} ->
                tks = [{:string, ln, i..j, string} | tks]
                lex(rest, input, updated_ln, j, tks)

              {:error, message} ->
                {:error, %DecodeError{message: message, line: ln}}
            end

          {rest, number_sign_count} ->
            {rest, j} = lex_identifier(rest, i + 1 + number_sign_count)
            identifier = copy_binary_part(input, i, j - i)
            tks = [{:bare_identifier, ln, i, identifier} | tks]
            lex(rest, input, ln, j, tks)
        end

      _ when is_decimal_char(char) ->
        case lex_number(src, i, ?+) do
          {rest, j, value} ->
            tks = [{:number, ln, i..j, value} | tks]
            lex(rest, input, ln, j, tks)

          {:error, message} ->
            {:error, %DecodeError{message: message, line: ln, byte_offset: i}}
        end

      <<next, _::bits>> = rest when is_sign_char(char) and is_decimal_char(next) ->
        case lex_number(rest, i + 1, char) do
          {rest, j, value} ->
            tks = [{:number, ln, i..j, value} | tks]
            lex(rest, input, ln, j, tks)

          {:error, message} ->
            {:error, %DecodeError{message: message, line: ln, byte_offset: i}}
        end

      rest when is_initial_identifier_char(char) ->
        {rest, j} = lex_identifier(rest, i + Chars.get_char_byte_length(char))

        token =
          case :binary.part(input, i, j - i) do
            "null" ->
              {:null, ln, i}

            "true" ->
              {:boolean, ln, i, true}

            "false" ->
              {:boolean, ln, i, false}

            identifier ->
              {:bare_identifier, ln, i, :binary.copy(identifier)}
          end

        lex(rest, input, ln, j, [token | tks])

      rest when char === ?= ->
        tks = [{:equals, ln, i} | tks]
        lex(rest, input, ln, i + 1, tks)

      rest when char === ?{ ->
        tks = [{:left_brace, ln, i} | tks]
        lex(rest, input, ln, i + 1, tks)

      rest when char === ?} ->
        tks = [{:right_brace, ln, i} | tks]
        lex(rest, input, ln, i + 1, tks)

      rest when char === ?( ->
        tks = [{:left_paren, ln, i} | tks]
        lex(rest, input, ln, i + 1, tks)

      rest when char === ?) ->
        tks = [{:right_paren, ln, i} | tks]
        lex(rest, input, ln, i + 1, tks)

      <<?/, rest::bits>> when char === ?/ ->
        {rest, j} = advance_until_newline(rest, i + 2)
        tks = [{:line_comment, ln, i..j} | tks]
        lex(rest, input, ln, j, tks)

      rest when char === ?; ->
        tks = [{:semicolon, ln, i} | tks]
        lex(rest, input, ln, i + 1, tks)

      rest when char === ?\\ ->
        tks = [{:continuation, ln, i} | tks]
        lex(rest, input, ln, i + 1, tks)

      <<?-, rest::bits>> when char === ?/ ->
        tks = [{:slashdash, ln, i} | tks]
        lex(rest, input, ln, i + 2, tks)

      rest when is_bom_char(char) ->
        tks = [{:bom, ln, i} | tks]
        lex(rest, input, ln, i + 1, tks)

      _ ->
        str = <<char::utf8>>

        message =
          if String.printable?(str) do
            "unrecognized byte: #{inspect(str, base: :hex)} (#{inspect(str)})"
          else
            "unrecognized byte: #{inspect(str, base: :hex)}"
          end

        {:error, %DecodeError{message: message, line: ln, byte_offset: i}}
    end
  end

  defp lex(<<>>, _, _, _, tks) do
    {:ok, Enum.reverse([{:eof} | tks])}
  end

  defp lex_identifier(<<char::utf8, rest::bits>>, i) when is_identifier_char(char) do
    lex_identifier(rest, i + Chars.get_char_byte_length(i))
  end

  defp lex_identifier(src, i) do
    {src, i}
  end

  defp lex_string(<<?", rest::bits>>, input, ln, skip, len, iodata) do
    next_idx = skip + len + 1
    string = extract_string(input, skip, len, iodata)
    {rest, ln, next_idx, string}
  end

  defp lex_string(<<char::utf8, rest::bits>>, input, ln, skip, len, iodata) do
    case rest do
      <<?\n, rest::bits>> when char === ?\r ->
        lex_string(rest, input, ln + 1, skip, len + 2, iodata)

      rest when is_newline_char(char) ->
        lex_string(rest, input, ln + 1, skip, len + Chars.get_char_byte_length(char), iodata)

      <<byte, rest::bits>> when char === ?\\ ->
        case byte do
          ?" ->
            lex_string_escape_char(rest, input, ln, skip, len, iodata, ?")

          ?n ->
            lex_string_escape_char(rest, input, ln, skip, len, iodata, ?\n)

          ?t ->
            lex_string_escape_char(rest, input, ln, skip, len, iodata, ?\t)

          ?\\ ->
            lex_string_escape_char(rest, input, ln, skip, len, iodata, <<?\\, ?\\>>)

          ?u ->
            case rest do
              <<"{", rest::bits>> ->
                case parse_unicode_escape(rest, input, skip + len + 3, 0) do
                  {:error, _message} = error ->
                    error

                  {rest, codepoint, char_advance} ->
                    lex_string_escape_char(
                      rest,
                      input,
                      ln,
                      skip,
                      len,
                      iodata,
                      <<codepoint::utf8>>,
                      char_advance + 3
                    )
                end

              _ ->
                {:error, "invalid escape in string"}
            end

          ?r ->
            lex_string_escape_char(rest, input, ln, skip, len, iodata, ?\r)

          ?/ ->
            lex_string_escape_char(rest, input, ln, skip, len, iodata, ?/)

          ?b ->
            lex_string_escape_char(rest, input, ln, skip, len, iodata, ?\b)

          ?f ->
            lex_string_escape_char(rest, input, ln, skip, len, iodata, ?\f)

          _ ->
            {:error, "invalid escape in string"}
        end

      rest ->
        lex_string(rest, input, ln, skip, len + Chars.get_char_byte_length(char), iodata)
    end
  end

  defp lex_string(<<>>, _input, _ln, _skip, _len, _iodata) do
    {:error, "unterminated string meets end of file"}
  end

  defp lex_string_escape_char(src, input, ln, skip, len, iodata, escape_value, skip_inc \\ 2) do
    if len == 0 do
      lex_string(src, input, ln, skip + skip_inc, 0, [iodata | [escape_value]])
    else
      part = :binary.part(input, skip, len)
      lex_string(src, input, ln, skip + len + skip_inc, 0, [iodata, part | [escape_value]])
    end
  end

  defp lex_raw_string(<<?", rest::bits>>, input, ln, skip, len, iodata, number_sign_count) do
    case count_contiguous_number_signs(rest, 0) do
      {rest, ^number_sign_count} ->
        next_idx = skip + len + 1 + number_sign_count
        string = extract_string(input, skip, len, iodata)
        {rest, ln, next_idx, string}

      {rest, bytes_scanned} ->
        len = len + 1 + bytes_scanned
        lex_raw_string(rest, input, ln, skip, len, iodata, number_sign_count)
    end
  end

  defp lex_raw_string(<<char::utf8, rest::bits>>, input, ln, skip, len, iodata, number_sign_count) do
    case rest do
      <<?\n, rest::bits>> when char === ?\r ->
        lex_raw_string(rest, input, ln + 1, skip, len + 2, iodata, number_sign_count)

      rest when is_newline_char(char) ->
        len = len + Chars.get_char_byte_length(char)
        lex_raw_string(rest, input, ln + 1, skip, len, iodata, number_sign_count)

      rest when char === ?\\ ->
        if len == 0 do
          iodata = [iodata | [<<?\\, ?\\>>]]
          skip = skip + 1
          lex_raw_string(rest, input, ln, skip, 0, iodata, number_sign_count)
        else
          part = :binary.part(input, skip, len)
          iodata = [iodata | [part, <<?\\, ?\\>>]]
          skip = skip + len + 1
          lex_raw_string(rest, input, ln, skip, 0, iodata, number_sign_count)
        end

      rest ->
        len = len + Chars.get_char_byte_length(char)
        lex_raw_string(rest, input, ln, skip, len, iodata, number_sign_count)
    end
  end

  defp lex_raw_string(<<>>, _input, _ln, _iodata, _skip, _len, _number_sign_count) do
    {:error, "unterminated string meets end of file"}
  end

  defp lex_number(<<?0, ?x, rest::bits>>, skip, sign) do
    case rest do
      <<next, rest::bits>> when is_hexadecimal_char(next) ->
        {rest, count, value} = parse_hexadecimal(rest, 1, [sign, next])
        {rest, skip + 2 + count, value}

      _ ->
        {:error, "invalid numeric literal"}
    end
  end

  defp lex_number(<<?0, ?b, rest::bits>>, skip, sign) do
    case rest do
      <<next, rest::bits>> when is_binary_char(next) ->
        {rest, count, value} = parse_binary(rest, 1, [sign, next])
        {rest, skip + 2 + count, value}

      _ ->
        {:error, "invalid numeric literal"}
    end
  end

  defp lex_number(<<?0, ?o, rest::bits>>, skip, sign) do
    case rest do
      <<next, rest::bits>> when is_octal_char(next) ->
        {rest, count, value} = parse_octal(rest, 1, [sign, next])
        {rest, skip + 2 + count, value}

      _ ->
        {:error, "invalid numeric literal"}
    end
  end

  defp lex_number(src, skip, sign) do
    case parse_decimal(src, 0, false, false, [sign]) do
      {rest, count, value} ->
        {rest, skip + count, value}

      error ->
        error
    end
  end

  defp parse_unicode_escape(<<?", _::bits>>, _input, _skip, _len) do
    {:error, "unterminated unicode escape"}
  end

  defp parse_unicode_escape(<<c, _::bits>>, _input, _skip, len)
       when len == 0 and c == ?} do
    {:error, "unicode escape must have at least 1 hex digit"}
  end

  defp parse_unicode_escape(<<c, _::bits>>, _input, _skip, len)
       when len > 6 and c != ?} do
    {:error, "unicode escape cannot be more than 6 hex digits"}
  end

  defp parse_unicode_escape(<<c, rest::bits>>, input, skip, len)
       when len <= 6 and c == ?} do
    case input |> :binary.part(skip, len) |> String.to_integer(16) do
      codepoint when codepoint in 0..0x10FFFF ->
        {rest, codepoint, len + 1}

      _ ->
        {:error, "unicode escape must be at most 10FFFF"}
    end
  end

  defp parse_unicode_escape(<<c, rest::bits>>, input, skip, len)
       when is_hexadecimal_char(c) do
    parse_unicode_escape(rest, input, skip, len + 1)
  end

  defp parse_unicode_escape(<<>>, _input, _skip, _len) do
    {:error, "unterminated string meets end of file"}
  end

  defp parse_unicode_escape(_src, _input, _skip, _len) do
    {:error, "invalid character in unicode escape"}
  end

  defp consume_consecutive_newlines(<<char::utf8, rest::bits>>, ln, i)
       when is_newline_char(char) do
    case rest do
      <<?\n, rest::bits>> when char === ?\r ->
        consume_consecutive_newlines(rest, ln + 1, i + 2)

      rest ->
        consume_consecutive_newlines(rest, ln + 1, i + Chars.get_char_byte_length(char))
    end
  end

  defp consume_consecutive_newlines(src, ln, i) do
    {src, ln, i}
  end

  defp consume_consecutive_whitespace(<<?\s, rest::bits>>, i) do
    consume_consecutive_whitespace(rest, i + 1)
  end

  defp consume_consecutive_whitespace(<<char::utf8, rest::bits>>, i)
       when is_whitespace_char(char) do
    consume_consecutive_whitespace(rest, i + Chars.get_char_byte_length(char))
  end

  defp consume_consecutive_whitespace(src, i) do
    {src, i}
  end

  defp advance_until_newline(<<char::utf8, rest::bits>>, i) when not is_newline_char(char) do
    advance_until_newline(rest, i + Chars.get_char_byte_length(char))
  end

  defp advance_until_newline(src, i) do
    {src, i}
  end

  defp count_contiguous_number_signs(<<?#, rest::bits>>, count) do
    count_contiguous_number_signs(rest, count + 1)
  end

  defp count_contiguous_number_signs(src, count) do
    {src, count}
  end

  defp parse_binary(<<char, rest::bits>>, count, iodata) when is_binary_char(char) do
    parse_binary(rest, count + 1, [iodata | [char]])
  end

  defp parse_binary(<<?_, rest::bits>>, count, iodata) do
    parse_binary(rest, count + 1, iodata)
  end

  defp parse_binary(src, count, iodata) do
    decimal =
      iodata
      |> IO.iodata_to_binary()
      |> String.to_integer(2)
      |> Decimal.new()

    {src, count, decimal}
  end

  defp parse_octal(<<char, rest::bits>>, count, iodata) when is_octal_char(char) do
    parse_octal(rest, count + 1, [iodata | [char]])
  end

  defp parse_octal(<<?_, rest::bits>>, count, iodata) do
    parse_octal(rest, count + 1, iodata)
  end

  defp parse_octal(src, count, iodata) do
    decimal =
      iodata
      |> IO.iodata_to_binary()
      |> String.to_integer(8)
      |> Decimal.new()

    {src, count, decimal}
  end

  defp parse_hexadecimal(<<char, rest::bits>>, count, iodata)
       when is_hexadecimal_char(char) do
    parse_hexadecimal(rest, count + 1, [iodata | [char]])
  end

  defp parse_hexadecimal(<<?_, src::binary>>, count, iodata) do
    parse_hexadecimal(src, count + 1, iodata)
  end

  defp parse_hexadecimal(src, count, iodata) do
    decimal =
      iodata
      |> IO.iodata_to_binary()
      |> String.to_integer(16)
      |> Decimal.new()

    {src, count, decimal}
  end

  defp parse_decimal(<<char, rest::bits>>, count, dot, exp, iodata)
       when is_decimal_char(char) do
    parse_decimal(rest, count + 1, dot, exp, [iodata | [char]])
  end

  defp parse_decimal(<<?_, rest::bits>>, count, dot, exp, iodata) do
    parse_decimal(rest, count + 1, dot, exp, iodata)
  end

  # This matches when we have already seen a "." in the number. For example:
  #
  #     10.01.1
  #          ^
  # Since 10.01 is a valid number literal and .[digit] is a valid identifier,
  # this isn't an error in the lexer. Therefore, we return the number parsed
  # up until the second "." (10.01) as our valid number literal.
  defp parse_decimal(<<?., _::bits>> = src, count, true, _exp, iodata) do
    parse_decimal(src, count, iodata)
  end

  # This matches when a character other than a digit (0-9) immediately follows
  # the ".". For example:
  #
  #     10._ or 10.a
  #        ^       ^
  # In this case, 10. is the start of a valid number literal, but it must have
  # at least one digit after the "." to be valid. Since that isn't the case here,
  # we return an error indicating the syntax is invalid.
  defp parse_decimal(<<?., char, _::bits>>, _count, false, _exp, _iodata)
       when not is_decimal_char(char) do
    {:error, "invalid numeric literal"}
  end

  # This matches when a dot is immediately followed by EOF.
  #
  #     10.
  #
  # In this case, the numeric literal is incomplete and is
  # therefore an error.
  defp parse_decimal(<<?.>>, _count, _dot, _exp, _iodata) do
    {:error, "invalid numeric literal"}
  end

  # At this point, we know that we:
  #
  #     1. Haven't already seen a "." in this number literal
  #     2. We know that the character after the "." is a digit
  #        (we handled the cases where it isn't above)
  #
  # So, as long we are not in the exponent part of a number literal,
  # this is a valid placement of a "." inside a number literal.
  defp parse_decimal(<<?., src::bits>>, count, false, false, iodata) do
    parse_decimal(src, count + 1, true, false, [iodata | [?.]])
  end

  # This matches when we have already seen an exponent in the number. For example:
  #
  #     2e10ear
  #         ^
  # Since 2e10 is a valid number literal and "e" is the start of a valid identifier,
  # this isn't an error in the lexer. Therefore, we return the number parsed up until
  # the second e (2e10) as our valid number literal.
  defp parse_decimal(<<char, _::bits>> = src, count, _dot, true, iodata) when is_exp_char(char) do
    parse_decimal(src, count, iodata)
  end

  # This matches when we have not already encountered an exponent in the number
  # and we see an "e" (or "E") followed by a digit. For example:
  #
  #     2e2
  #      ^^
  # This is the start of a valid exponent part of a number literal and so we
  # continue parsing.
  defp parse_decimal(<<c1, c2, src::bits>>, count, dot, false, iodata)
       when is_exp_char(c1) and is_decimal_char(c2) do
    parse_decimal(src, count + 2, dot, true, [iodata | [c1, c2]])
  end

  # This matches when we have not already encountered an exponent in the number
  # and we see an "e" (or "E") followed by a sign (+-) and then followed by a digit.
  # For example:
  #
  #     2e-2
  #      ^^^
  # This is the start of a valid exponent part of a number literal and so we
  # continue parsing.
  defp parse_decimal(<<c1, c2, c3, src::bits>>, count, dot, false, iodata)
       when is_exp_char(c1) and is_sign_char(c2) and is_decimal_char(c3) do
    parse_decimal(src, count + 3, dot, true, [iodata | [c1, c2, c3]])
  end

  # This matches when we have not already encountered an exponent in the number
  # and we see an "e" (or "E") followed by some character that is not a sign or
  # a digit (including EOF).
  #
  #     2e_2
  #      ^^
  # This is an invalid number literal and so we return an error indicating the
  # syntax is malformed.
  defp parse_decimal(<<c, _::bits>>, _count, _dot, false, _iodata) when is_exp_char(c) do
    {:error, "invalid numeric literal"}
  end

  defp parse_decimal(src, count, _dot, _exp, iodata) do
    parse_decimal(src, count, iodata)
  end

  defp parse_decimal(src, count, iodata) do
    decimal =
      iodata
      |> IO.iodata_to_binary()
      |> Decimal.new()

    {src, count, decimal}
  end

  @compile {:inline, extract_string: 4}
  defp extract_string(input, skip, len, iodata) do
    case iodata do
      [] when len > 0 ->
        copy_binary_part(input, skip, len)

      [] when len == 0 ->
        ""

      iodata when len == 0 ->
        IO.iodata_to_binary(iodata)

      iodata when len > 0 ->
        part = :binary.part(input, skip, len)
        IO.iodata_to_binary([iodata | [part]])
    end
  end

  @compile {:inline, copy_binary_part: 3}
  defp copy_binary_part(binary, start_idx, length) do
    binary
    |> :binary.part(start_idx, length)
    |> :binary.copy()
  end
end
