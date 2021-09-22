defmodule Kdl.LexerTest do
  use ExUnit.Case, async: true

  alias Kdl.Lexer

  alias Kdl.Token.{
    Eof,
    LeftBrace,
    RightBrace,
    Newline,
    Whitespace,
    Null,
    Boolean,
    BinaryNumber,
    OctalNumber,
    DecimalNumber,
    HexadecimalNumber,
    String,
    RawString,
    BareIdentifier,
    LineComment,
    MultilineComment,
    NodeComment,
    Continuation
  }

  defp lex_at(src, at) do
    {:ok, tokens} = Lexer.lex(src)
    tokens |> Enum.at(at)
  end

  defp lex_hd(src) do
    lex_at(src, 0)
  end

  test "correctly parses null" do
    assert %Null{} = lex_hd("null")
  end

  test "correctly parses booleans" do
    assert %Boolean{value: false} = lex_hd("false")
    assert %Boolean{value: true} = lex_hd("true")
  end

  test "correctly parses newlines" do
    assert %Newline{value: "\n"} = lex_hd("\n")
    assert %Newline{value: "\r\n"} = lex_hd("\r\n")

    other_newline_chars = [0x000C, 0x0085, 0x2028, 0x2029]

    Enum.each(other_newline_chars, fn char ->
      char_str = to_string([char])
      assert assert %Newline{value: ^char_str} = lex_hd(char_str)
    end)
  end

  test "correctly parses whitespace" do
    assert %Whitespace{value: " "} = lex_hd(" ")
    assert %Whitespace{value: "\t"} = lex_hd("\t")

    other_whitespace_chars = [
      0x00A0,
      0x1680,
      0x2000,
      0x2001,
      0x2002,
      0x2003,
      0x2004,
      0x2005,
      0x2006,
      0x2007,
      0x2008,
      0x2009,
      0x200A,
      0x202F,
      0x205F,
      0x3000,
      0xFEFF
    ]

    Enum.each(other_whitespace_chars, fn char ->
      char_str = to_string([char])
      assert assert %Whitespace{value: ^char_str} = lex_hd(char_str)
    end)
  end

  test "correctly parses bare identifiers" do
    assert %BareIdentifier{value: "foo"} = lex_hd("foo")
    assert %BareIdentifier{value: "foo_bar"} = lex_hd("foo_bar")
    assert %BareIdentifier{value: "foo-bar"} = lex_hd("foo-bar")
    assert %BareIdentifier{value: "foo.bar"} = lex_hd("foo.bar")
    assert %BareIdentifier{value: "foo123"} = lex_hd("foo123")

    assert %BareIdentifier{value: "rawstring"} = lex_hd("rawstring")
    assert %BareIdentifier{value: "r###notarawstring"} = lex_hd("r###notarawstring")

    legal_bare_ident = "foo123~!@#$%^&*.:'|?+"
    assert %BareIdentifier{value: ^legal_bare_ident} = lex_hd(legal_bare_ident)
  end

  test "correctly parses escaped strings" do
    assert %String{value: "hello world"} = lex_hd("\"hello world\"")
    assert %String{value: "hello\nworld"} = lex_hd("\"hello\\nworld\"")
    assert %String{value: "hello\tworld"} = lex_hd("\"hello\\tworld\"")
    assert %String{value: "hello\t\"world\""} = lex_hd("\"hello\\t\\\"world\\\"\"")

    assert {:error, "[line 1] invalid escape in string"} = Lexer.lex("\"hello\\kworld\"")

    assert %String{value: "\n"} = lex_hd("\"\\u{0a}\"")
    assert %String{value: "ü"} = lex_hd("\"\\u{00FC}\"")
    assert %String{value: "􏿿"} = lex_hd("\"\\u{10FFFF}\"")

    assert {:error, "[line 1] invalid character in unicode escape"} = Lexer.lex("\"\\u{tty}\"")

    assert {:error, "[line 1] unicode escape must have at least 1 hex digit"} =
             Lexer.lex("\"\\u{}\"")

    assert {:error, "[line 1] unterminated unicode escape"} = Lexer.lex("\"\\u{0a\"")
    assert {:error, "[line 1] unterminated unicode escape"} = Lexer.lex("\"\\u{\"")

    assert {:error, "[line 1] unterminated string meets end of file"} = Lexer.lex("node \"name")
    assert {:error, "[line 1] unterminated string meets end of file"} = Lexer.lex("node \"\\u{")
  end

  test "correctly parses raw strings" do
    assert %RawString{value: "hello world"} = lex_hd("r\"hello world\"")
    assert %RawString{value: "hello\\nworld"} = lex_hd("r\"hello\\nworld\"")
    assert %RawString{value: "hello\\tworld"} = lex_hd("r\"hello\\tworld\"")
    assert %RawString{value: "hello\nworld"} = lex_hd("r\"hello\nworld\"")
    assert %RawString{value: "hello\tworld"} = lex_hd("r\"hello\tworld\"")

    assert %RawString{value: "hello world"} = lex_hd("r#\"hello world\"#")
    assert %RawString{value: "hello\\nworld"} = lex_hd("r#\"hello\\nworld\"#")
    assert %RawString{value: "hello\\tworld"} = lex_hd("r#\"hello\\tworld\"#")
    assert %RawString{value: "hello\nworld"} = lex_hd("r#\"hello\nworld\"#")
    assert %RawString{value: "hello\tworld"} = lex_hd("r#\"hello\tworld\"#")
    assert %RawString{value: "hello\\t\"world\""} = lex_hd("r#\"hello\\t\"world\"\"#")

    assert %RawString{value: "hello world"} = lex_hd("r##\"hello world\"##")
    assert %RawString{value: "hello \"# world"} = lex_hd("r##\"hello \"# world\"##")
    assert %RawString{value: "hello world"} = lex_hd("r####\"hello world\"####")

    assert %RawString{value: "hello \" \"### world"} = lex_hd("r####\"hello \" \"### world\"####")

    assert {:error, "[line 1] unterminated string meets end of file"} = Lexer.lex("node r\"name")
    assert {:error, "[line 1] unterminated string meets end of file"} = Lexer.lex("node r#\"name")

    assert {:error, "[line 1] unterminated string meets end of file"} =
             Lexer.lex("node r##\"name\"# 10")
  end

  test "correctly parses binary" do
    assert %BinaryNumber{value: "0b0"} = lex_hd("0b0")
    assert %BinaryNumber{value: "0b1"} = lex_hd("0b1")
    assert %BinaryNumber{value: "0b010011"} = lex_hd("0b010011")

    assert %BinaryNumber{value: "+0b010011"} = lex_hd("+0b010011")
    assert %BinaryNumber{value: "-0b010011"} = lex_hd("-0b010011")

    assert %BinaryNumber{value: "0b010_011"} = lex_hd("0b010_011")
    assert %BinaryNumber{value: "+0b010_011"} = lex_hd("+0b010_011")
    assert %BinaryNumber{value: "-0b010_011"} = lex_hd("-0b010_011")
    assert %BinaryNumber{value: "0b010___011"} = lex_hd("0b010___011")
    assert %BinaryNumber{value: "0b0_1_0_0_1_1"} = lex_hd("0b0_1_0_0_1_1")
    assert %BinaryNumber{value: "0b010011_"} = lex_hd("0b010011_")
    assert %BinaryNumber{value: "0b010011___"} = lex_hd("0b010011___")

    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0b_010011")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0b")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0b5")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0ba")
  end

  test "correctly parses octal" do
    assert %OctalNumber{value: "0o0"} = lex_hd("0o0")
    assert %OctalNumber{value: "0o7"} = lex_hd("0o7")
    assert %OctalNumber{value: "0o312467"} = lex_hd("0o312467")

    assert %OctalNumber{value: "+0o312467"} = lex_hd("+0o312467")
    assert %OctalNumber{value: "-0o312467"} = lex_hd("-0o312467")

    assert %OctalNumber{value: "0o312_467"} = lex_hd("0o312_467")
    assert %OctalNumber{value: "+0o312_467"} = lex_hd("+0o312_467")
    assert %OctalNumber{value: "-0o312_467"} = lex_hd("-0o312_467")
    assert %OctalNumber{value: "0o312___467"} = lex_hd("0o312___467")
    assert %OctalNumber{value: "0o3_1_2_4_6_7"} = lex_hd("0o3_1_2_4_6_7")
    assert %OctalNumber{value: "0o312467_"} = lex_hd("0o312467_")
    assert %OctalNumber{value: "0o312467___"} = lex_hd("0o312467___")

    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0o_312467")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0o")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0o8")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0oa")
  end

  test "correctly parses hexadecimal" do
    assert %HexadecimalNumber{value: "0x0"} = lex_hd("0x0")
    assert %HexadecimalNumber{value: "0xF"} = lex_hd("0xF")
    assert %HexadecimalNumber{value: "0x0A93BD8"} = lex_hd("0x0A93BD8")
    assert %HexadecimalNumber{value: "0x0a93bd8"} = lex_hd("0x0a93bd8")
    assert %HexadecimalNumber{value: "0x0A93bd8"} = lex_hd("0x0A93bd8")

    assert %HexadecimalNumber{value: "+0x0A93BD8"} = lex_hd("+0x0A93BD8")
    assert %HexadecimalNumber{value: "-0x0A93BD8"} = lex_hd("-0x0A93BD8")

    assert %HexadecimalNumber{value: "0x0A93_BD8"} = lex_hd("0x0A93_BD8")
    assert %HexadecimalNumber{value: "+0x0A93_BD8"} = lex_hd("+0x0A93_BD8")
    assert %HexadecimalNumber{value: "-0x0A93_BD8"} = lex_hd("-0x0A93_BD8")
    assert %HexadecimalNumber{value: "0x0A93___BD8"} = lex_hd("0x0A93___BD8")
    assert %HexadecimalNumber{value: "0x0_A_9_3_B_D_8"} = lex_hd("0x0_A_9_3_B_D_8")
    assert %HexadecimalNumber{value: "0x0A93bd8_"} = lex_hd("0x0A93bd8_")
    assert %HexadecimalNumber{value: "0x0A93bd8___"} = lex_hd("0x0A93bd8___")

    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0x_0A93bd8")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0x")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0xG")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("0xg")
  end

  test "correctly parses decimal" do
    assert %DecimalNumber{value: "0"} = lex_hd("0")
    assert %DecimalNumber{value: "9"} = lex_hd("9")
    assert %DecimalNumber{value: "124578"} = lex_hd("124578")

    assert %DecimalNumber{value: "+124578"} = lex_hd("+124578")
    assert %DecimalNumber{value: "-124578"} = lex_hd("-124578")

    assert %DecimalNumber{value: "124_578"} = lex_hd("124_578")
    assert %DecimalNumber{value: "+124_578"} = lex_hd("+124_578")
    assert %DecimalNumber{value: "-124_578"} = lex_hd("-124_578")
    assert %DecimalNumber{value: "124___578"} = lex_hd("124___578")
    assert %DecimalNumber{value: "1_2_4_5_7_8"} = lex_hd("1_2_4_5_7_8")
    assert %DecimalNumber{value: "124578_"} = lex_hd("124578_")
    assert %DecimalNumber{value: "124578___"} = lex_hd("124578___")

    assert %DecimalNumber{value: "124.578"} = lex_hd("124.578")
    assert %DecimalNumber{value: "+124.578"} = lex_hd("+124.578")
    assert %DecimalNumber{value: "-124.578"} = lex_hd("-124.578")
    assert %DecimalNumber{value: "12_4.57_8"} = lex_hd("12_4.57_8")
    assert %DecimalNumber{value: "124_.57__8_"} = lex_hd("124_.57__8_")

    assert %DecimalNumber{value: "10e256"} = lex_hd("10e256")
    assert %DecimalNumber{value: "10E256"} = lex_hd("10E256")
    assert %DecimalNumber{value: "10e+256"} = lex_hd("10e+256")
    assert %DecimalNumber{value: "10e-256"} = lex_hd("10e-256")
    assert %DecimalNumber{value: "10E+256"} = lex_hd("10E+256")
    assert %DecimalNumber{value: "10E-256"} = lex_hd("10E-256")
    assert %DecimalNumber{value: "+10e-256"} = lex_hd("+10e-256")
    assert %DecimalNumber{value: "-10e+256"} = lex_hd("-10e+256")
    assert %DecimalNumber{value: "10e+2_56"} = lex_hd("10e+2_56")
    assert %DecimalNumber{value: "1_0e+2_56"} = lex_hd("1_0e+2_56")

    assert %DecimalNumber{value: "124.10e256"} = lex_hd("124.10e256")
    assert %DecimalNumber{value: "124.10e+256"} = lex_hd("124.10e+256")
    assert %DecimalNumber{value: "124.10e-256"} = lex_hd("124.10e-256")
    assert %DecimalNumber{value: "+124.10e-256"} = lex_hd("+124.10e-256")
    assert %DecimalNumber{value: "-124.10e-256"} = lex_hd("-124.10e-256")

    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("124._578")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("10e_256")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("10e-_256")
    assert {:error, "[line 1] invalid number literal"} = Lexer.lex("10e+_256")
  end

  test "correctly parses line comments" do
    assert %LineComment{value: "// my comment"} = lex_hd("// my comment\nnode name=\"node name\"")

    assert %LineComment{value: "//key=\"value\" 10"} = lex_at("node//key=\"value\" 10", 1)
  end

  test "correctly parses multiline comments" do
    assert %MultilineComment{value: "/* multiline comment */"} = lex_hd("/* multiline comment */")

    {:ok, tokens} = Lexer.lex("node /*key=\"value\" 10*/ 20")

    assert [
             %BareIdentifier{value: "node"},
             %Whitespace{value: " "},
             %MultilineComment{value: "/*key=\"value\" 10*/"},
             %Whitespace{value: " "},
             %DecimalNumber{value: "20"},
             %Eof{}
           ] = tokens

    {:ok, tokens} = Lexer.lex("node {/*\n  /* nested */\n  /* comments */\n*/  child 20\n}")

    assert [
             %BareIdentifier{value: "node"},
             %Whitespace{value: " "},
             %LeftBrace{},
             %MultilineComment{value: "/*\n  /* nested */\n  /* comments */\n*/"},
             %Whitespace{value: " "},
             %Whitespace{value: " "},
             %BareIdentifier{value: "child"},
             %Whitespace{value: " "},
             %DecimalNumber{value: "20"},
             %Newline{value: "\n"},
             %RightBrace{},
             %Eof{}
           ] = tokens

    assert {:error, "[line 1] unterminated multiline comment"} =
             Lexer.lex("/* multiline comment ")

    assert {:error, "[line 1] unterminated multiline comment"} =
             Lexer.lex("/* multiline /* comment */ ")
  end

  test "correctly parses node comments" do
    {:ok, tokens} = Lexer.lex("/-node 1")

    assert [
             %NodeComment{},
             %BareIdentifier{value: "node"},
             %Whitespace{value: " "},
             %DecimalNumber{value: "1"},
             %Eof{}
           ] = tokens

    {:ok, tokens} = Lexer.lex("node /-1")

    assert [
             %BareIdentifier{value: "node"},
             %Whitespace{value: " "},
             %NodeComment{},
             %DecimalNumber{value: "1"},
             %Eof{}
           ] = tokens

    {:ok, tokens} = Lexer.lex("node/-1")

    assert [
             %BareIdentifier{value: "node"},
             %NodeComment{},
             %DecimalNumber{value: "1"},
             %Eof{}
           ] = tokens
  end

  test "correctly parses line continuations" do
    assert %Continuation{} = lex_at("node \\\n10", 2)
    assert %Continuation{} = lex_at("node\\\n10", 1)
    assert %Continuation{} = lex_at("node \\ // comment\n  10", 2)
    assert %Continuation{} = lex_at("node \\//comment\n10", 2)
    assert %Continuation{} = lex_at("node\\//comment\n10", 1)
  end

  test "errors correctly report line number" do
    assert {:error, "[line 2] invalid character in unicode escape"} =
             Lexer.lex("node_1\nnode_2 \"\\u{invalid unicode escape}\" \nnode_3")

    assert {:error, "[line 5] invalid number literal"} =
             Lexer.lex("node_1 /*multi\nline\ncomment\n*/\nnode_2 0bnotnumber")

    assert {:error, "[line 6] invalid number literal"} =
             Lexer.lex("node_1 \"\nmulti\nline\nstring\n\"\nnode_2 0bnotnumber")

    assert {:error, "[line 7] invalid number literal"} =
             Lexer.lex("node_1 r\"\nmulti\nline\nraw\nstring\n\"\nnode_2 0bnotnumber")
  end
end
