defmodule Kdl.Encoder do
  alias Kdl.Chars
  alias Kdl.Node

  import Kdl.Chars, only: [is_initial_identifier_char: 1]

  @tab_size 4

  @kw_true "true"
  @kw_false "false"
  @kw_null "null"

  @spec encode(list(Node.t())) :: {:ok, binary}
  def encode(nodes) when is_list(nodes) do
    {:ok, encode(nodes, [])}
  end

  defp encode([node | nodes], iodata) do
    encode(nodes, encode_node(node, 0, iodata))
  end

  defp encode([], iodata) do
    IO.iodata_to_binary(iodata)
  end

  defp encode_node(%{} = node, depth, iodata) do
    iodata
    |> encode_name(node)
    |> encode_values(node)
    |> encode_properties(node)
    |> encode_children(depth, node)
    |> encode_terminator()
  end

  defp encode_name(iodata, node) do
    [iodata | [encode_identifier(node.name)]]
  end

  defp encode_values(iodata, node) do
    node.values
    |> Enum.reduce(iodata, fn value, iodata ->
      [iodata | [?\s, encode_value(value)]]
    end)
  end

  defp encode_properties(iodata, node) do
    node.properties
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.reduce(iodata, fn {key, value}, iodata ->
      pair = [?\s, encode_identifier(key), ?=, encode_value(value)]
      [iodata | pair]
    end)
  end

  defp encode_children(iodata, _depth, %{children: []}) do
    iodata
  end

  defp encode_children(iodata, depth, %{children: children}) do
    block_open = '\s{\n'

    block_close =
      if depth == 0 do
        '}'
      else
        [build_indent_iodata(depth) | '}']
      end

    child_indent = build_indent_iodata(depth + 1)

    encoded_children =
      children
      |> Enum.reduce([], fn value, iodata ->
        node = encode_node(value, depth + 1, [])
        [iodata | [child_indent, node]]
      end)

    [iodata, block_open, encoded_children | block_close]
  end

  defp encode_terminator(iodata) do
    [iodata | '\n']
  end

  defp encode_identifier("null"), do: ~s|"null"|
  defp encode_identifier("true"), do: ~s|"true"|
  defp encode_identifier("false"), do: ~s|"false"|

  defp encode_identifier(<<char::utf8, _::bits>> = value)
       when is_initial_identifier_char(char) do
    encode_string(value, true)
  end

  defp encode_identifier(value), do: encode_string(value, false)

  defp encode_value(value) when is_binary(value), do: encode_string(value, false)
  defp encode_value(value) when is_number(value), do: to_string(value)
  defp encode_value(true), do: @kw_true
  defp encode_value(false), do: @kw_false
  defp encode_value(nil), do: @kw_null

  defp encode_string(value, prefer_bare_identifier) do
    {iodata, valid_bare_identifier} = encode_string(value, value, [], 0, 0, true)

    if prefer_bare_identifier and valid_bare_identifier do
      iodata
    else
      [?", iodata | '"']
    end
  end

  invalid_bare_identifier_range = Range.new(0, Chars.min_valid_identifier_char() - 1)

  invalid_bare_identifier_chars =
    (Enum.to_list(invalid_bare_identifier_range) ++ Chars.non_identifier_chars())
    |> Enum.uniq()
    |> Enum.reject(&Map.has_key?(Chars.escape_char_map(), &1))
    |> Enum.sort()

  {single_byte_invalid_bare_identifier_chars, multi_byte_invalid_bare_identifier_chars} =
    Enum.split_with(
      invalid_bare_identifier_chars,
      fn char -> char <= Chars.max_1_byte_char() end
    )

  for byte <- 0..Chars.max_1_byte_char() do
    cond do
      Map.has_key?(Chars.escape_char_map(), byte) ->
        defp encode_string(<<unquote(byte), rest::bits>>, original, acc, skip, len, _) do
          part = binary_part(original, skip, len)
          acc = [acc, part | [unquote(Map.fetch!(Chars.escape_char_map(), byte))]]
          encode_string(rest, original, acc, skip + len + 1, 0, false)
        end

      Enum.member?(single_byte_invalid_bare_identifier_chars, byte) ->
        defp encode_string(<<unquote(byte), rest::bits>>, original, acc, skip, len, _) do
          encode_string(rest, original, acc, skip, len + 1, false)
        end

      true ->
        defp encode_string(
               <<unquote(byte), rest::bits>>,
               original,
               acc,
               skip,
               len,
               valid_bare_identifier
             ) do
          encode_string(rest, original, acc, skip, len + 1, valid_bare_identifier)
        end
    end
  end

  for invalid_bare_identifier_char <- multi_byte_invalid_bare_identifier_chars do
    char_byte_length = Chars.get_char_byte_length(invalid_bare_identifier_char)

    defp encode_string(<<char::utf8, rest::bits>>, original, acc, skip, len, _)
         when char === unquote(invalid_bare_identifier_char) do
      encode_string(rest, original, acc, skip, len + unquote(char_byte_length), false)
    end
  end

  defp encode_string(<<char::utf8, rest::bits>>, original, acc, skip, len, valid_bare_identifier)
       when char <= unquote(Chars.max_2_byte_char()) do
    encode_string(rest, original, acc, skip, len + 2, valid_bare_identifier)
  end

  defp encode_string(<<char::utf8, rest::bits>>, original, acc, skip, len, valid_bare_identifier)
       when char <= unquote(Chars.max_3_byte_char()) do
    encode_string(rest, original, acc, skip, len + 3, valid_bare_identifier)
  end

  defp encode_string(<<char::utf8, rest::bits>>, original, acc, skip, len, valid_bare_identifier)
       when char <= unquote(Chars.max_valid_identifier_char()) do
    encode_string(rest, original, acc, skip, len + 4, valid_bare_identifier)
  end

  defp encode_string(<<_char::utf8, rest::bits>>, original, acc, skip, len, _) do
    encode_string(rest, original, acc, skip, len + 4, false)
  end

  defp encode_string(<<>>, original, _acc, 0, _len, valid_bare_identifier) do
    {original, valid_bare_identifier}
  end

  defp encode_string(<<>>, original, acc, skip, len, valid_bare_identifier) do
    part = binary_part(original, skip, len)
    {[acc | [part]], valid_bare_identifier}
  end

  defp build_indent_iodata(n, tab_size \\ @tab_size)

  defp build_indent_iodata(n, tab_size) when n > 0 do
    for _ <- 1..(n * tab_size), do: ?\s
  end
end
