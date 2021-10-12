defmodule ExKdl.DecodeError do
  @type t :: %__MODULE__{message: String.t(), line: non_neg_integer}

  defexception [:message, line: nil]

  def message(%{message: message, line: line}) when is_integer(line) do
    "Line #{line}: #{message}"
  end

  def message(%{message: message}) do
    message
  end
end

defmodule ExKdl.EncodeError do
  @type t :: %__MODULE__{message: String.t()}

  defexception [:message]
end
