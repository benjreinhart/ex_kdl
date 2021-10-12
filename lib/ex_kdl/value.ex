defmodule ExKdl.Value do
  @moduledoc """
  The struct to represent KDL values.

  Its fields are:

  * `value` - The underlying value
  * `type` - The (optional) type of the value
  """
  @enforce_keys :value
  defstruct [:value, type: nil]

  @type t :: %__MODULE__{
          value: any,
          type: nil | binary
        }

  @doc false
  @spec new(any, binary) :: t
  def new(value, type) do
    %__MODULE__{value: value, type: type}
  end
end
