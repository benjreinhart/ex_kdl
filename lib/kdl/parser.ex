defmodule Kdl.Parser do
  alias Kdl.Node
  alias Kdl.Token
  alias Kdl.Value

  import Kdl.Token, only: [is_type: 2]

  import Kdl.Parser.Utils

  defguardp is_whitespace(token)
            when is_type(token, :whitespace) or
                   is_type(token, :multiline_comment) or
                   is_type(token, :bom)

  defguardp is_linespace(token)
            when is_whitespace(token) or
                   is_type(token, :newline) or
                   is_type(token, :line_comment)

  defguardp is_keyword(token)
            when is_type(token, :null) or is_type(token, :boolean)

  defguardp is_value(token)
            when is_type(token, :string) or is_type(token, :number) or is_keyword(token)

  defguardp is_identifier(token)
            when is_type(token, :bare_identifier) or is_type(token, :string)

  @spec parse(list(tuple)) :: {:ok, list(Node.t())} | {:error, binary()}

  def parse(tokens) do
    case parse_nodes(tokens) do
      {:match, [], nodes} ->
        {:ok, nodes}

      {:match, [token], nodes} when is_type(token, :eof) ->
        {:ok, nodes}

      {:match, _, _} ->
        {:error, "failed to parse KDL document"}
    end
  end

  defp parse_nodes(tokens) do
    tokens = discard_while(tokens, &is_linespace/1)

    case parse_node(tokens) do
      {:match, tokens, node} ->
        {:match, tokens, nodes} = parse_nodes(tokens)

        nodes =
          if is_nil(node) do
            nodes
          else
            [node | nodes]
          end

        {:match, tokens, nodes}

      :nomatch ->
        tokens = discard_while(tokens, &is_linespace/1)
        {:match, tokens, []}
    end
  end

  defp parse_node(tokens) do
    with {:match, tokens, is_commented} <- tokens |> zero_or_one(&node_comment/1),
         {:match, tokens, _} <- tokens |> zero_or_more(&whitespace/1),
         {:match, tokens, type} <- tokens |> zero_or_one(&type_annotation/1),
         {:match, tokens, name} <- tokens |> one(&identifier/1),
         {:match, tokens, props_and_vals} <- tokens |> zero_or_more(&node_props_and_vals/1),
         {:match, tokens, children} <- tokens |> zero_or_more(&node_children/1),
         {:match, tokens, _} <- tokens |> zero_or_more(&node_space/1),
         {:match, tokens, _} <- tokens |> one(&node_terminator/1) do
      if is_commented do
        {:match, tokens, nil}
      else
        {properties, values} = process_props_and_vals(props_and_vals)

        kdl_node = %Node{
          name: name,
          type: type,
          values: values,
          properties: properties,
          children: List.flatten(children)
        }

        {:match, tokens, kdl_node}
      end
    end
  end

  defp node_children(tokens) do
    with {:match, tokens, _} <- tokens |> zero_or_more(&node_space/1),
         {:match, tokens, is_commented} <- tokens |> zero_or_one(&node_comment/1),
         {:match, tokens, _} <- tokens |> zero_or_more(&node_space/1),
         {:match, tokens, _} <- tokens |> one(&left_brace/1),
         {:match, tokens, nodes} <- tokens |> one(&parse_nodes/1),
         {:match, tokens, _} <- tokens |> one(&right_brace/1) do
      if is_commented do
        {:match, tokens, []}
      else
        {:match, tokens, nodes}
      end
    end
  end

  defp node_props_and_vals(tokens) do
    with {:match, tokens, _} <- tokens |> one_or_more(&node_space/1),
         {:match, tokens, is_commented} <- tokens |> zero_or_one(&node_comment/1),
         {:match, tokens, _} <- tokens |> zero_or_more(&node_space/1),
         {:match, tokens, prop_or_val} <- tokens |> one(&node_property/1, or: &node_value/1) do
      if is_commented do
        {:match, tokens, nil}
      else
        {:match, tokens, prop_or_val}
      end
    end
  end

  defp node_property(tokens) do
    with {:match, tokens, key} <- tokens |> one(&identifier/1),
         {:match, tokens, _} <- tokens |> one(&equals/1),
         {:match, tokens, value} <- tokens |> one(&node_value/1) do
      {:match, tokens, {key, value}}
    end
  end

  defp node_value(tokens) do
    with {:match, tokens, type} <- tokens |> zero_or_one(&type_annotation/1),
         {:match, tokens, val} <- tokens |> one(&value/1) do
      {:match, tokens, Value.new(val, type)}
    end
  end

  defp node_terminator(tokens) do
    one(
      tokens,
      &line_comment/1,
      or: &newline/1,
      or: &semicolon/1,
      or: &eof/1
    )
  end

  defp node_space(tokens) do
    one(
      tokens,
      &escape_line/1,
      or: fn tokens -> tokens |> one_or_more(&whitespace/1) end
    )
  end

  defp escape_line(tokens) do
    with {:match, tokens, _} <- tokens |> zero_or_more(&whitespace/1),
         {:match, tokens, _} <- tokens |> one(&continuation/1),
         {:match, tokens, _} <- tokens |> zero_or_more(&whitespace/1),
         {:match, tokens, _} <- tokens |> zero_or_one(&line_comment/1),
         {:match, _, _} = match <- tokens |> one(&newline/1) do
      match
    end
  end

  terminals = %{
    eof: nil,
    semicolon: nil,
    left_brace: nil,
    right_brace: nil,
    equals: nil,
    continuation: nil,
    newline: nil,
    node_comment: true,
    line_comment: nil
  }

  for {terminal, value} <- terminals do
    defp unquote(terminal)([token | tokens]) when is_type(token, unquote(terminal)) do
      {:match, tokens, unquote(value)}
    end

    defp unquote(terminal)(_tokens) do
      :nomatch
    end
  end

  productions = ~w(
    whitespace
    identifier
    value
  )a

  for production <- productions do
    defp unquote(production)([token | tokens])
         when unquote(String.to_atom("is_#{production}"))(token) do
      {:match, tokens, Token.value(token)}
    end

    defp unquote(production)(_tokens) do
      :nomatch
    end
  end

  defp type_annotation([t1, t2, t3 | tokens])
       when is_type(t1, :left_paren) and is_identifier(t2) and is_type(t3, :right_paren) do
    {:match, tokens, Token.value(t2)}
  end

  defp type_annotation(_tokens) do
    :nomatch
  end

  defp process_props_and_vals(props_and_vals) do
    process_props_and_vals(props_and_vals, %{}, [])
  end

  defp process_props_and_vals([property | rest], props, vals) when is_tuple(property) do
    case property do
      {key, %Value{} = value} ->
        process_props_and_vals(rest, Map.put(props, key, value), vals)

      # This happens when a property was commented out with a slashdash.
      # In that case, we need to ignore the property.
      {_key, nil} ->
        process_props_and_vals(rest, props, vals)
    end
  end

  defp process_props_and_vals([value | rest], props, vals) do
    case value do
      %Value{} = value ->
        process_props_and_vals(rest, props, [value | vals])

      # This happens when a value was commented out with a slashdash.
      # In that case, we need to ignore the value.
      nil ->
        process_props_and_vals(rest, props, vals)
    end
  end

  defp process_props_and_vals([], props, vals) do
    {props, Enum.reverse(vals)}
  end
end
