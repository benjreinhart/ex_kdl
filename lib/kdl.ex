defmodule Kdl do
  alias Kdl.Encoder
  alias Kdl.Errors.{DecodeError, EncodeError, SyntaxError}
  alias Kdl.Lexer
  alias Kdl.Parser

  @spec decode(binary) :: {:ok, list(Kdl.Node.t())} | {:error, any}

  def decode(encoded) when is_binary(encoded) do
    with {:ok, tokens} <- Lexer.lex(encoded) do
      Parser.parse(tokens)
    end
  end

  def decode(_) do
    {:error, "Argument to decode/1 must be a KDL-encoded binary"}
  end

  @spec decode!(binary) :: list(Kdl.Node.t())

  def decode!(encoded) do
    case decode(encoded) do
      {:ok, nodes} ->
        nodes

      # TODO: proper and consistent error handling
      {:error, %SyntaxError{message: message, line: line}} ->
        raise DecodeError, message: "Line #{line}: #{message}"

      {:error, message} ->
        raise DecodeError, message: message
    end
  end

  @spec encode(list(Kdl.Node.t())) :: {:ok, binary} | {:error, binary}

  def encode(nodes) when is_list(nodes) do
    Encoder.encode(nodes)
  end

  def encode(_) do
    {:error, "Argument to encode/1 must be a list of KDL nodes"}
  end

  @spec encode!([Kdl.Node.t()]) :: binary
  def encode!(decoded) do
    case encode(decoded) do
      {:ok, encoded} ->
        encoded

      {:error, message} ->
        raise EncodeError, message: message
    end
  end
end
