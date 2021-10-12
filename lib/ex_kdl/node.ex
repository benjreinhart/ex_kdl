defmodule ExKdl.Node do
  @moduledoc """
  The struct to represent KDL nodes.

  Its fields are:

  * `name` - The name of the node
  * `type` - The (optional) type of the node
  * `values` - A list of the node's values, represented as
    `ExKdl.Value` structs
  * `properties` - A map of the node's properties, using binary
    keys and `ExKdl.Value` structs for values
  * `children` - A list of the node's children which are also `ExKdl.Node`s
  """
  @enforce_keys :name
  defstruct [
    :name,
    type: nil,
    values: [],
    properties: %{},
    children: []
  ]

  @type t :: %__MODULE__{
          name: binary,
          type: nil | binary,
          values: list(ExKdl.Value.t()),
          properties: %{binary => ExKdl.Value.t()},
          children: list(t)
        }
end
