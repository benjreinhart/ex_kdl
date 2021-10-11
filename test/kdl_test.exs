defmodule Kdl.KdlTest do
  use ExUnit.Case, async: true

  alias Kdl.Errors.{DecodeError, EncodeError}

  import Kdl, only: [decode: 1, decode!: 1, encode: 1, encode!: 1]

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
    test_name = "input/#{file_name}"
    tag = String.to_atom(test_name)

    if Map.has_key?(expected_file_map, file_name) do
      @tag tag
      test test_name do
        assert {:ok, decoded} = decode(unquote(file_contents))
        assert {:ok, encoded} = encode(decoded)
        assert unquote(Map.fetch!(expected_file_map, file_name)) == encoded
      end
    else
      @tag tag
      test test_name do
        assert {:error, _message} = decode(unquote(file_contents))
      end
    end
  end

  describe "exception variants" do
    test "decode! successfully decodes a valid KDL-encoded document" do
      assert [
               %Kdl.Node{
                 name: "node",
                 type: nil,
                 values: [%Kdl.Value{value: %Decimal{coef: 100}, type: nil}],
                 properties: %{},
                 children: []
               }
             ] = decode!("node 100")
    end

    test "decode! raises DecodeError on failure" do
      assert_raise DecodeError, "Line 1: invalid number literal", fn ->
        decode!("node 1.")
      end
    end

    test "encode! successfully encodes a list of KDL nodes" do
      assert "node 100\n" =
               encode!([
                 %Kdl.Node{
                   name: "node",
                   type: nil,
                   values: [%Kdl.Value{value: %Decimal{coef: 100}, type: nil}],
                   properties: %{},
                   children: []
                 }
               ])
    end

    test "encode! raises EncodeError on failure" do
      assert_raise EncodeError, "Argument to encode/1 must be a list of KDL nodes", fn ->
        encode!(1)
      end
    end
  end
end
