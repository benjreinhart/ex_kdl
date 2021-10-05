defmodule Kdl.Node do
  @enforce_keys :name
  defstruct [:name, values: [], properties: %{}, children: []]

  @type t :: %__MODULE__{
    name: binary,
    values: list(any),
    properties: %{binary => any},
    children: list(t)
  }
end
