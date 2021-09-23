defmodule Kdl.Errors do
  defmodule SyntaxError do
    @enforce_keys [:line, :message]
    defstruct [:line, :message]

    @spec new(integer, binary) :: %__MODULE__{line: integer, message: binary}
    def new(line, message) when is_integer(line) and is_binary(message) do
      %__MODULE__{line: line, message: message}
    end
  end
end
