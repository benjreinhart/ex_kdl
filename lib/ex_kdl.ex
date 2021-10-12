defmodule ExKdl do
  alias ExKdl.Encoder
  alias ExKdl.Errors.{DecodeError, EncodeError, SyntaxError}
  alias ExKdl.Lexer
  alias ExKdl.Parser

  @spec decode(binary) :: {:ok, list(ExKdl.Node.t())} | {:error, any}

  def decode(encoded) when is_binary(encoded) do
    with {:ok, tokens} <- Lexer.lex(encoded) do
      Parser.parse(tokens)
    end
  end

  def decode(_) do
    {:error, "Argument to decode/1 must be a KDL-encoded binary"}
  end

  @spec decode!(binary) :: list(ExKdl.Node.t())

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

  @spec encode(list(ExKdl.Node.t())) :: {:ok, binary} | {:error, binary}

  def encode(nodes) when is_list(nodes) do
    Encoder.encode(nodes)
  end

  def encode(_) do
    {:error, "Argument to encode/1 must be a list of KDL nodes"}
  end

  @spec encode!([ExKdl.Node.t()]) :: binary
  def encode!(decoded) do
    case encode(decoded) do
      {:ok, encoded} ->
        encoded

      {:error, message} ->
        raise EncodeError, message: message
    end
  end
end
