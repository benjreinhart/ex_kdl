# ExKdl

![Elixir tests](https://github.com/benjreinhart/ex_kdl/actions/workflows/elixir.yml/badge.svg)

A robust and efficient decoder and encoder for the [KDL Document Language](https://kdl.dev).

ExKdl conforms to the KDL 1.0.0 [spec](https://github.com/kdl-org/kdl/blob/main/SPEC.md) and is tested against the official [test suite](https://github.com/kdl-org/kdl/tree/main/tests).

## Installation

ExKdl can be installed by adding `ex_kdl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:ex_kdl, "~> 0.1.0-rc2"}]
end
```

## Basic Usage

```elixir
iex(1)> nodes = ExKdl.decode!("node 100 key=\"value\" 10_000 /* comment */ {\n    child_1\n    child_2\n}\n")
[
  %ExKdl.Node{
    children: [
      %ExKdl.Node{
        children: [],
        name: "child_1",
        properties: %{},
        type: nil,
        values: []
      },
      %ExKdl.Node{
        children: [],
        name: "child_2",
        properties: %{},
        type: nil,
        values: []
      }
    ],
    name: "node",
    properties: %{"key" => %ExKdl.Value{type: nil, value: "value"}},
    type: nil,
    values: [
      %ExKdl.Value{type: nil, value: %Decimal{coef: 100}},
      %ExKdl.Value{type: nil, value: %Decimal{coef: 10000}}
    ]
  }
]

iex(2)> ExKdl.encode!(nodes)
"node 100 10000 key=\"value\" {\n    child_1\n    child_2\n}\n"
```

Full documentation can be found at [https://hexdocs.pm/ex_kdl](https://hexdocs.pm/ex_kdl).

## Developing

This repo includes the [kdl-org/kdl](https://github.com/kdl-org/kdl) repo listed as a submodule for testing purposes.

```
git clone --recurse-submodules <this repo>
```

Or, if already cloned, initialize the submodule with:

```
git submodule update --init
```

### Dependencies

```
mix deps.get
```

### Running tests

```
mix test
```

To run a specific test from the kdl-org test suite, use the `--only` option and pass it the `path` (where `path` is `input/<filename>.kdl`). For example:

```
mix test --only input/raw_string_just_backslash.kdl
```

## License

ExKdl is released under the MIT license ([LICENSE.txt](LICENSE.txt)).
