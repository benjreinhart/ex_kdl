# Kdl

This library is a WIP elixir implementation of the [KDL Document Language](https://kdl.dev).

## Initial release

Blocking TODOs are captured in [#1](https://github.com/benjreinhart/kdl-ex/issues/1)

## Documentation

_Note: this library is a WIP and subject to change._

```elixir
{:ok, nodes} = Kdl.decode("node 100 key=\"value\" 10_000 /* comment */ {\n  child_1 ; child_2\n}")

IO.inspect(nodes)
# [
#   %{
#     name: "node",
#     values: [100, 10000],
#     properties: %{"key" => "value"},
#     children: [
#       %{children: [], name: "child_1", properties: %{}, values: []},
#       %{children: [], name: "child_2", properties: %{}, values: []}
#     ]
#   }
# ]

{:ok, encoded} = Kdl.encode(nodes)

IO.puts(encoded)
# node 100 10000 key="value" {
#     child_1
#     child_2
# }
#
```

#### decode(binary()) :: {:ok, list(map())} | {:error, any()}

Attempts to decode the given binary. If the binary is a valid KDL document, then `{:ok, nodes}` is returned where nodes is a list of maps. A node has the following shape:

```elixir
%{
  name: binary(),
  values: list(any())
  properties: map(),
  children: list(map()),
}
```

#### encode(list(map)) :: {:ok, binary()} | {:error, any()}

Attemps to encode the given KDL nodes.
