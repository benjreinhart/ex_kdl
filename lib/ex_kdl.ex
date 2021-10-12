defmodule ExKdl do
  @moduledoc """
  A robust and efficient decoder and encoder for the KDL Document Language.
  """

  alias ExKdl.{DecodeError, EncodeError, Encoder, Lexer, Node, Parser}

  @doc """
  Decodes a KDL-encoded document from the `input` binary.

  ## Examples

      iex> ExKdl.decode("node 10")
      {:ok,
       [
         %ExKdl.Node{
           name: "node",
           type: nil,
           values: [%ExKdl.Value{type: nil, value: %Decimal{coef: 10}}],
           properties: %{},
           children: []
         }
       ]}

      iex> ExKdl.decode(~s|node "unterminated string|)
      {:error,
       %ExKdl.DecodeError{
         line: 1,
         message: "unterminated string meets end of file"
       }}
  """
  @spec decode(binary) :: {:ok, [Node.t()]} | {:error, DecodeError.t()}
  def decode(input) when is_binary(input) do
    with {:ok, tokens} <- Lexer.lex(input) do
      Parser.parse(tokens)
    end
  end

  def decode(_) do
    {:error, %DecodeError{message: "Argument to decode/1 must be a KDL-encoded binary"}}
  end

  @doc """
  Decodes a KDL-encoded document from the `input` binary.

  Similar to `decode/1` except it will raise in the event of an error.

  ## Examples

      iex> ExKdl.decode!("node 10")
      [
        %ExKdl.Node{
          name: "node",
          type: nil,
          values: [%ExKdl.Value{type: nil, value: %Decimal{coef: 10}}],
          properties: %{},
          children: []
        }
      ]

      iex> ExKdl.decode!(~s|node "unterminated string|)
      ** (ExKdl.DecodeError) Line 1: unterminated string meets end of file
  """
  @spec decode!(binary) :: [Node.t()]
  def decode!(input) do
    case decode(input) do
      {:ok, nodes} ->
        nodes

      {:error, error} ->
        raise error
    end
  end

  @doc """
  Encodes a list of `ExKdl.Node` structs into a KDL-encoded binary.

  ## Examples

      iex> ExKdl.encode([%ExKdl.Node{name: "node", values: [%ExKdl.Value{value: %Decimal{coef: 10}}]}])
      {:ok, "node 10\\n"}

      iex> ExKdl.encode(nil)
      {:error, %ExKdl.EncodeError{message: "Argument to encode/1 must be a list of KDL nodes"}}
  """
  @spec encode([Node.t()]) :: {:ok, binary} | {:error, EncodeError.t()}
  def encode(input) when is_list(input) do
    Encoder.encode(input)
  end

  def encode(_) do
    {:error, %EncodeError{message: "Argument to encode/1 must be a list of KDL nodes"}}
  end

  @doc """
  Encodes a list of `ExKdl.Node` structs into a KDL-encoded binary.

  Similar to `encode/1` except it will raise in the event of an error.

  ## Examples

      iex> ExKdl.encode!([%ExKdl.Node{name: "node", values: [%ExKdl.Value{value: %Decimal{coef: 10}}]}])
      "node 10\\n"

      iex> ExKdl.encode!(nil)
      ** (ExKdl.EncodeError) Argument to encode/1 must be a list of KDL nodes
  """
  @spec encode!([Node.t()]) :: binary
  def encode!(input) do
    case encode(input) do
      {:ok, encoded} ->
        encoded

      {:error, error} ->
        raise error
    end
  end
end
