defmodule ExKdl.Node do
  @enforce_keys :name
  defstruct [:name, type: nil, values: [], properties: %{}, children: []]

  @type t :: %__MODULE__{
          name: binary,
          type: nil | binary,
          values: list(ExKdl.Value.t()),
          properties: %{binary => ExKdl.Value.t()},
          children: list(t)
        }
end
