# Kdl

This library is a WIP elixir implementation of the [KDL Document Language](https://kdl.dev).

## Initial release

Blocking TODOs are captured in [#1](https://github.com/benjreinhart/kdl-ex/issues/1)

## Documentation

_Note: this library is a WIP and subject to change._

```elixir
{:ok, nodes} = Kdl.decode("node 100 key=\"value\" 10_000 /* comment */ {\n    child_1\n    child_2\n}\n")

IO.inspect(nodes)
# [
#   %Kdl.Node{
#     children: [
#       %Kdl.Node{
#         children: [],
#         name: "child_1",
#         properties: %{},
#         type: nil,
#         values: []
#       },
#       %Kdl.Node{
#         children: [],
#         name: "child_2",
#         properties: %{},
#         type: nil,
#         values: []
#       }
#     ],
#     name: "node",
#     properties: %{"key" => %Kdl.Value{type: nil, value: "value"}},
#     type: nil,
#     values: [
#       %Kdl.Value{type: nil, value: #Decimal<100>},
#       %Kdl.Value{type: nil, value: #Decimal<10000>}
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

_Note: All numbers are parsed into [Decimals](https://hexdocs.pm/decimal/readme.html)._

#### Kdl.Node.t()

The type of a KDL node. Defined as

```elixir
@type t :: Kdl.Node{
  name: binary,
  type: nil | binary,
  values: list(Kdl.Value.t()),
  properties: %{binary => Kdl.Value.t()},
  children: list(t)
}
```

#### Kdl.Value.t()

The type of a KDL value. Defined as

```elixir
@type t :: Kdl.Value{
  value: any,
  type: nil | binary,
}
```

### Functions

#### Kdl.decode(binary) :: {:ok, list(Kdl.Node.t())} | {:error, any}

Attempts to decode the given binary. If the binary is a valid KDL document, then `{:ok, nodes}` is returned where `nodes` is a list of `Kdl.Node` structs.

#### Kdl.decode!(binary) :: list(Kdl.Node.t())

Attempts to decode the given binary. If the binary is a valid KDL document, it returns a list of `Kdl.Node` structs.

Raises a `Kdl.Errors.DecodeError` if the argument is not a valid KDL-encoded document.

#### Kdl.encode(list(Kdl.Node.t())) :: {:ok, binary} | {:error, binary}

Attempts to encode the given argument. If the argument can be successfully encoded, then it returns `{:ok, encoded}` where `encoded` is a KDL-encoded binary.

#### Kdl.encode!(list(Kdl.Node.t())) :: binary

Attempts to encode the given argument. If the argument can be successfully encoded, it returns a KDL-encoded binary.

Raises a `Kdl.Errors.EncodeError` if the argument cannot be encoded.

## Developing

This repo includes the [kdl-org/kdl](https://github.com/kdl-org/kdl) repo listed as a submodule for testing purposes.

```
git clone --recurse-submodules <this repo>
```

Or, if already cloned, initialize the submodule with:

```
git submodule update --init
```

### Running tests

```
mix test
```

To run a specific test from the kdl-org test suite, use the `--only` option and pass it the `path` (where `path` is `input/<filename>.kdl`). For example:

```
mix test --only input/raw_string_just_backslash.kdl
```
