defmodule Kdl.Encoder do
  @tab_size 4

  @kw_true "true"
  @kw_false "false"
  @kw_null "null"

  @type kdl_node :: %{
          :children => kdl_node,
          :name => binary,
          :properties => map,
          :values => list(any)
        }

  @spec encode(list(kdl_node)) :: {:ok, binary}
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

  defp encode_identifier(value) do
    encode_string(value, true)
  end

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

  escape_chars = %{
    ?\b => "\\b",
    ?\t => "\\t",
    ?\n => "\\n",
    ?\f => "\\f",
    ?\r => "\\r",
    ?" => "\\\"",
    ?/ => "\/",
    ?\\ => "\\"
  }

  whitespace_chars = [
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

  newline_chars = [
    0x000A,
    0x000D,
    0x000C,
    0x0085,
    0x2028,
    0x2029
  ]

  non_identifier_chars = [
    ?",
    ?(,
    ?),
    ?,,
    ?/,
    ?;,
    ?<,
    ?=,
    ?>,
    ?[,
    ?\\,
    ?],
    ?{,
    ?}
  ]

  invalid_bare_identifier_chars =
    (Enum.to_list(0..0x20) ++ whitespace_chars ++ newline_chars ++ non_identifier_chars)
    |> Enum.uniq()
    |> Enum.reject(&Map.has_key?(escape_chars, &1))
    |> Enum.sort()

  {invalid_bare_identifier_byte, invalid_bare_identifier_bytes} =
    Enum.split_with(
      invalid_bare_identifier_chars,
      fn char -> char <= 127 end
    )

  for byte <- 0..127 do
    cond do
      Map.has_key?(escape_chars, byte) ->
        defp encode_string(<<unquote(byte), rest::bits>>, original, acc, skip, len, _) do
          part = binary_part(original, skip, len)
          acc = [acc, part | [unquote(Map.fetch!(escape_chars, byte))]]
          encode_string(rest, original, acc, skip + len + 1, 0, false)
        end

      Enum.member?(invalid_bare_identifier_byte, byte) ->
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

  for non_ident_char <- invalid_bare_identifier_bytes do
    num_bytes =
      cond do
        non_ident_char <= 0x7FF -> 2
        non_ident_char <= 0xFFFF -> 3
        true -> 4
      end

    defp encode_string(<<char::utf8, rest::bits>>, original, acc, skip, len, _)
         when char === unquote(non_ident_char) do
      encode_string(rest, original, acc, skip, len + unquote(num_bytes), false)
    end
  end

  defp encode_string(<<char::utf8, rest::bits>>, original, acc, skip, len, valid_bare_identifier)
       when char <= 0x7FF do
    encode_string(rest, original, acc, skip, len + 2, valid_bare_identifier)
  end

  defp encode_string(<<char::utf8, rest::bits>>, original, acc, skip, len, valid_bare_identifier)
       when char <= 0xFFFF do
    encode_string(rest, original, acc, skip, len + 3, valid_bare_identifier)
  end

  defp encode_string(<<_char::utf8, rest::bits>>, original, acc, skip, len, valid_bare_identifier) do
    encode_string(rest, original, acc, skip, len + 4, valid_bare_identifier)
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
