defmodule ExKdl do
  @moduledoc """
  A robust and efficient decoder and encoder for the KDL Document Language.
  """

  alias ExKdl.Encoder
  alias ExKdl.Errors.{DecodeError, EncodeError, SyntaxError}
  alias ExKdl.Lexer
  alias ExKdl.Parser

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
       %ExKdl.Errors.SyntaxError{
         line: 1,
         message: "unterminated string meets end of file"
       }}

      iex> ExKdl.decode([])
      {:error, "Argument to decode/1 must be a KDL-encoded binary"}
  """
  @spec decode(binary) :: {:ok, list(ExKdl.Node.t())} | {:error, any}
  def decode(input) when is_binary(input) do
    with {:ok, tokens} <- Lexer.lex(input) do
      Parser.parse(tokens)
    end
  end

  def decode(_) do
    {:error, "Argument to decode/1 must be a KDL-encoded binary"}
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
      ** (ExKdl.Errors.DecodeError) Line 1: unterminated string meets end of file
  """
  @spec decode!(binary) :: list(ExKdl.Node.t())
  def decode!(input) do
    case decode(input) do
      {:ok, nodes} ->
        nodes

      # TODO: proper and consistent error handling
      {:error, %SyntaxError{message: message, line: line}} ->
        raise DecodeError, message: "Line #{line}: #{message}"

      {:error, message} ->
        raise DecodeError, message: message
    end
  end

  @doc """
  Encodes a list of `ExKdl.Node` structs into a KDL-encoded binary.

  ## Examples

      iex> ExKdl.encode([%ExKdl.Node{name: "node", values: [%ExKdl.Value{value: %Decimal{coef: 10}}]}])
      {:ok, "node 10\\n"}

      iex> ExKdl.encode(nil)
      {:error, "Argument to encode/1 must be a list of KDL nodes"}
  """
  @spec encode(list(ExKdl.Node.t())) :: {:ok, binary} | {:error, binary}
  def encode(input) when is_list(input) do
    Encoder.encode(input)
  end

  def encode(_) do
    {:error, "Argument to encode/1 must be a list of KDL nodes"}
  end

  @doc """
  Encodes a list of `ExKdl.Node` structs into a KDL-encoded binary.

  Similar to `encode/1` except it will raise in the event of an error.

  ## Examples

      iex> ExKdl.encode!([%ExKdl.Node{name: "node", values: [%ExKdl.Value{value: %Decimal{coef: 10}}]}])
      "node 10\\n"

      iex> ExKdl.encode!(nil)
      ** (ExKdl.Errors.EncodeError) Argument to encode/1 must be a list of KDL nodes
  """
  @spec encode!(list(ExKdl.Node.t())) :: binary
  def encode!(input) do
    case encode(input) do
      {:ok, encoded} ->
        encoded

      {:error, message} ->
        raise EncodeError, message: message
    end
  end
end
