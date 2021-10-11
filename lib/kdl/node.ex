defmodule Kdl.Node do
  @enforce_keys :name
  defstruct [:name, type: nil, values: [], properties: %{}, children: []]

  @type t :: %__MODULE__{
          name: binary,
          type: nil | binary,
          values: list(Kdl.Value.t()),
          properties: %{binary => Kdl.Value.t()},
          children: list(t)
        }
end
