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
#   %Kdl.Node{
#     name: "node",
#     values: [100, 10000],
#     properties: %{"key" => "value"},
#     children: [
#       %Kdl.Node{children: [], name: "child_1", properties: %{}, values: []},
#       %Kdl.Node{children: [], name: "child_2", properties: %{}, values: []}
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

### Types

#### Kdl.Node.t()

The type of a KDL node. Defined as

```elixir
@type t :: %Kdl.Node{
  name: binary,
  values: list(any),
  properties: %{binary => any},
  children: list(t)
}
```

### Functions

#### Kdl.decode(binary()) :: {:ok, list(Kdl.Node.t())} | {:error, any()}

Attempts to decode the given binary. If the binary is a valid KDL document, then `{:ok, nodes}` is returned where nodes is a list of `Kdl.Node` structs.

#### Kdl.encode(list(Kdl.Node.t())) :: {:ok, binary()}

Encodes the given KDL nodes.

## Developing

This repo includes the [kdl-org/kdl](https://github.com/kdl-org/kdl) repo listed as a submodule for testing purposes.

```
git clone --recurse-submodules <this repo>
```

Or, if already cloned, initialize the submodule with:

```
git submodule update --init
```

To run tests:

```
mix test
```

### Running a specific test

The test runner will execute the kdl-org tests. To run a specific test, use the `--only` option and pass it the `path` (where `path` is `input/<filename>.kdl`). For example:

```
mix test --only input/raw_string_just_backslash.kdl
```
