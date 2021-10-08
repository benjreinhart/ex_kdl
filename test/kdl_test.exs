defmodule Kdl.KdlTest do
  use ExUnit.Case, async: true

  import Kdl, only: [encode: 1, decode: 1]

  this_dir = Path.dirname(__ENV__.file)
  root_dir = Path.join(this_dir, "..")

  tests_dir =
    root_dir
    |> Path.join("kdl")
    |> Path.join("tests")
    |> Path.join("test_cases")

  input_dir = Path.join(tests_dir, "input")
  expected_dir = Path.join(tests_dir, "expected_kdl")

  input_file_map =
    "#{input_dir}/*.kdl"
    |> Path.wildcard()
    |> Enum.map(&{Path.basename(&1), File.read!(&1)})
    |> Map.new()

  expected_file_map =
    "#{expected_dir}/*.kdl"
    |> Path.wildcard()
    |> Enum.map(&{Path.basename(&1), File.read!(&1)})
    |> Map.new()

  unless map_size(input_file_map) > 0 and map_size(expected_file_map) > 0 do
    test "against the spec tests in the kdl-org/kdl submodule" do
      flunk("""
      Could not find the spec tests. This probably means the kdl-org/kdl submodule is not initialized.
      Run `git submodule update --init` to initialize the kdl-org/kdl submodule and re-run the tests.
      """)
    end
  end

  for {file_name, file_contents} <- input_file_map do
    tag = file_name |> Path.rootname(".kdl") |> String.to_atom()

    if Map.has_key?(expected_file_map, file_name) do
      @tag tag
      test "input/#{file_name}" do
        assert {:ok, decoded} = decode(unquote(file_contents))
        assert {:ok, encoded} = encode(decoded)
        assert unquote(Map.fetch!(expected_file_map, file_name)) == encoded
      end
    else
      @tag tag
      test "input/#{file_name}" do
        assert {:error, _message} = decode(unquote(file_contents))
      end
    end
  end
end
