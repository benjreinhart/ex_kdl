defmodule Kdl.Value do
  @enforce_keys :value
  defstruct [:value, type: nil]

  @type t :: %__MODULE__{
          value: any,
          type: nil | binary
        }

  @spec new(any, binary) :: t
  def new(value, type) do
    %__MODULE__{value: value, type: type}
  end
end
