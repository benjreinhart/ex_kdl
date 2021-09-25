defmodule Kdl.LexerTest do
  use ExUnit.Case, async: true

  alias Kdl.Lexer

  alias Kdl.Errors.SyntaxError

  defp lex_at(src, at) do
    {:ok, tokens} = Lexer.lex(src)
    tokens |> Enum.at(at)
  end

  defp lex_hd(src) do
    lex_at(src, 0)
  end

  test "correctly parses BOM" do
    assert {:bom, 1} = lex_hd("\u{FEFF}")
  end

  test "correctly parses null" do
    assert {:null, 1} = lex_hd("null")
  end

  test "correctly parses booleans" do
    assert {:boolean, 1, false} = lex_hd("false")
    assert {:boolean, 1, true} = lex_hd("true")
  end

  test "correctly parses newlines" do
    assert {:newline, 1, "\n"} = lex_hd("\n")
    assert {:newline, 1, "\r\n"} = lex_hd("\r\n")

    other_newline_chars = [0x000C, 0x0085, 0x2028, 0x2029]

    Enum.each(other_newline_chars, fn char ->
      char_str = to_string([char])
      assert assert {:newline, 1, ^char_str} = lex_hd(char_str)
    end)
  end

  test "correctly parses whitespace" do
    assert {:whitespace, 1, " "} = lex_hd(" ")
    assert {:whitespace, 1, "\t"} = lex_hd("\t")

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
      0x3000
    ]

    Enum.each(other_whitespace_chars, fn char ->
      char_str = to_string([char])
      assert assert {:whitespace, 1, ^char_str} = lex_hd(char_str)
    end)
  end

  test "correctly parses bare identifiers" do
    assert {:bare_identifier, 1, "foo"} = lex_hd("foo")
    assert {:bare_identifier, 1, "foo_bar"} = lex_hd("foo_bar")
    assert {:bare_identifier, 1, "foo-bar"} = lex_hd("foo-bar")
    assert {:bare_identifier, 1, "foo.bar"} = lex_hd("foo.bar")
    assert {:bare_identifier, 1, "foo123"} = lex_hd("foo123")

    assert {:bare_identifier, 1, "rawstring"} = lex_hd("rawstring")
    assert {:bare_identifier, 1, "r###notarawstring"} = lex_hd("r###notarawstring")

    legal_bare_ident = "foo123~!@#$%^&*.:'|?+"
    assert {:bare_identifier, 1, ^legal_bare_ident} = lex_hd(legal_bare_ident)
  end

  test "correctly parses escaped strings" do
    assert {:string, 1, "hello world"} = lex_hd("\"hello world\"")
    assert {:string, 1, "hello\nworld"} = lex_hd("\"hello\\nworld\"")
    assert {:string, 1, "hello\tworld"} = lex_hd("\"hello\\tworld\"")
    assert {:string, 1, "hello\t\"world\""} = lex_hd("\"hello\\t\\\"world\\\"\"")

    assert {:error, %SyntaxError{line: 1, message: "invalid escape in string"}} =
             Lexer.lex("\"hello\\kworld\"")

    assert {:string, 1, "\n"} = lex_hd("\"\\u{0a}\"")
    assert {:string, 1, "ü"} = lex_hd("\"\\u{00FC}\"")
    assert {:string, 1, "􏿿"} = lex_hd("\"\\u{10FFFF}\"")

    assert {:error, %SyntaxError{line: 1, message: "invalid character in unicode escape"}} =
             Lexer.lex("\"\\u{tty}\"")

    assert {:error,
            %SyntaxError{line: 1, message: "unicode escape must have at least 1 hex digit"}} =
             Lexer.lex("\"\\u{}\"")

    assert {:error, %SyntaxError{line: 1, message: "unterminated unicode escape"}} =
             Lexer.lex("\"\\u{0a\"")

    assert {:error, %SyntaxError{line: 1, message: "unterminated unicode escape"}} =
             Lexer.lex("\"\\u{\"")

    assert {:error, %SyntaxError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node \"name")

    assert {:error, %SyntaxError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node \"\\u{")
  end

  test "correctly parses raw strings" do
    assert {:raw_string, 1, "hello world"} = lex_hd("r\"hello world\"")
    assert {:raw_string, 1, "hello\\nworld"} = lex_hd("r\"hello\\nworld\"")
    assert {:raw_string, 1, "hello\\tworld"} = lex_hd("r\"hello\\tworld\"")
    assert {:raw_string, 1, "hello\nworld"} = lex_hd("r\"hello\nworld\"")
    assert {:raw_string, 1, "hello\tworld"} = lex_hd("r\"hello\tworld\"")

    assert {:raw_string, 1, "hello world"} = lex_hd("r#\"hello world\"#")
    assert {:raw_string, 1, "hello\\nworld"} = lex_hd("r#\"hello\\nworld\"#")
    assert {:raw_string, 1, "hello\\tworld"} = lex_hd("r#\"hello\\tworld\"#")
    assert {:raw_string, 1, "hello\nworld"} = lex_hd("r#\"hello\nworld\"#")
    assert {:raw_string, 1, "hello\tworld"} = lex_hd("r#\"hello\tworld\"#")
    assert {:raw_string, 1, "hello\\t\"world\""} = lex_hd("r#\"hello\\t\"world\"\"#")

    assert {:raw_string, 1, "hello world"} = lex_hd("r##\"hello world\"##")
    assert {:raw_string, 1, "hello \"# world"} = lex_hd("r##\"hello \"# world\"##")
    assert {:raw_string, 1, "hello world"} = lex_hd("r####\"hello world\"####")

    assert {:raw_string, 1, "hello \" \"### world"} = lex_hd("r####\"hello \" \"### world\"####")

    assert {:error, %SyntaxError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node r\"name")

    assert {:error, %SyntaxError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node r#\"name")

    assert {:error, %SyntaxError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node r##\"name\"# 10")
  end

  test "correctly parses binary" do
    assert {:binary_number, 1, "0b0"} = lex_hd("0b0")
    assert {:binary_number, 1, "0b1"} = lex_hd("0b1")
    assert {:binary_number, 1, "0b010011"} = lex_hd("0b010011")

    assert {:binary_number, 1, "+0b010011"} = lex_hd("+0b010011")
    assert {:binary_number, 1, "-0b010011"} = lex_hd("-0b010011")

    assert {:binary_number, 1, "0b010_011"} = lex_hd("0b010_011")
    assert {:binary_number, 1, "+0b010_011"} = lex_hd("+0b010_011")
    assert {:binary_number, 1, "-0b010_011"} = lex_hd("-0b010_011")
    assert {:binary_number, 1, "0b010___011"} = lex_hd("0b010___011")
    assert {:binary_number, 1, "0b0_1_0_0_1_1"} = lex_hd("0b0_1_0_0_1_1")
    assert {:binary_number, 1, "0b010011_"} = lex_hd("0b010011_")
    assert {:binary_number, 1, "0b010011___"} = lex_hd("0b010011___")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} =
             Lexer.lex("0b_010011")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} = Lexer.lex("0b")
    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} = Lexer.lex("0b5")
    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} = Lexer.lex("0ba")
  end

  test "correctly parses octal" do
    assert {:octal_number, 1, "0o0"} = lex_hd("0o0")
    assert {:octal_number, 1, "0o7"} = lex_hd("0o7")
    assert {:octal_number, 1, "0o312467"} = lex_hd("0o312467")

    assert {:octal_number, 1, "+0o312467"} = lex_hd("+0o312467")
    assert {:octal_number, 1, "-0o312467"} = lex_hd("-0o312467")

    assert {:octal_number, 1, "0o312_467"} = lex_hd("0o312_467")
    assert {:octal_number, 1, "+0o312_467"} = lex_hd("+0o312_467")
    assert {:octal_number, 1, "-0o312_467"} = lex_hd("-0o312_467")
    assert {:octal_number, 1, "0o312___467"} = lex_hd("0o312___467")
    assert {:octal_number, 1, "0o3_1_2_4_6_7"} = lex_hd("0o3_1_2_4_6_7")
    assert {:octal_number, 1, "0o312467_"} = lex_hd("0o312467_")
    assert {:octal_number, 1, "0o312467___"} = lex_hd("0o312467___")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} =
             Lexer.lex("0o_312467")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} = Lexer.lex("0o")
    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} = Lexer.lex("0o8")
    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} = Lexer.lex("0oa")
  end

  test "correctly parses hexadecimal" do
    assert {:hexadecimal_number, 1, "0x0"} = lex_hd("0x0")
    assert {:hexadecimal_number, 1, "0xF"} = lex_hd("0xF")
    assert {:hexadecimal_number, 1, "0x0A93BD8"} = lex_hd("0x0A93BD8")
    assert {:hexadecimal_number, 1, "0x0a93bd8"} = lex_hd("0x0a93bd8")
    assert {:hexadecimal_number, 1, "0x0A93bd8"} = lex_hd("0x0A93bd8")

    assert {:hexadecimal_number, 1, "+0x0A93BD8"} = lex_hd("+0x0A93BD8")
    assert {:hexadecimal_number, 1, "-0x0A93BD8"} = lex_hd("-0x0A93BD8")

    assert {:hexadecimal_number, 1, "0x0A93_BD8"} = lex_hd("0x0A93_BD8")
    assert {:hexadecimal_number, 1, "+0x0A93_BD8"} = lex_hd("+0x0A93_BD8")
    assert {:hexadecimal_number, 1, "-0x0A93_BD8"} = lex_hd("-0x0A93_BD8")
    assert {:hexadecimal_number, 1, "0x0A93___BD8"} = lex_hd("0x0A93___BD8")
    assert {:hexadecimal_number, 1, "0x0_A_9_3_B_D_8"} = lex_hd("0x0_A_9_3_B_D_8")
    assert {:hexadecimal_number, 1, "0x0A93bd8_"} = lex_hd("0x0A93bd8_")
    assert {:hexadecimal_number, 1, "0x0A93bd8___"} = lex_hd("0x0A93bd8___")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} =
             Lexer.lex("0x_0A93bd8")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} = Lexer.lex("0x")
    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} = Lexer.lex("0xG")
    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} = Lexer.lex("0xg")
  end

  test "correctly parses decimal" do
    assert {:decimal_number, 1, "0"} = lex_hd("0")
    assert {:decimal_number, 1, "9"} = lex_hd("9")
    assert {:decimal_number, 1, "124578"} = lex_hd("124578")

    assert {:decimal_number, 1, "+124578"} = lex_hd("+124578")
    assert {:decimal_number, 1, "-124578"} = lex_hd("-124578")

    assert {:decimal_number, 1, "124_578"} = lex_hd("124_578")
    assert {:decimal_number, 1, "+124_578"} = lex_hd("+124_578")
    assert {:decimal_number, 1, "-124_578"} = lex_hd("-124_578")
    assert {:decimal_number, 1, "124___578"} = lex_hd("124___578")
    assert {:decimal_number, 1, "1_2_4_5_7_8"} = lex_hd("1_2_4_5_7_8")
    assert {:decimal_number, 1, "124578_"} = lex_hd("124578_")
    assert {:decimal_number, 1, "124578___"} = lex_hd("124578___")

    assert {:decimal_number, 1, "124.578"} = lex_hd("124.578")
    assert {:decimal_number, 1, "+124.578"} = lex_hd("+124.578")
    assert {:decimal_number, 1, "-124.578"} = lex_hd("-124.578")
    assert {:decimal_number, 1, "12_4.57_8"} = lex_hd("12_4.57_8")
    assert {:decimal_number, 1, "124_.57__8_"} = lex_hd("124_.57__8_")

    assert {:decimal_number, 1, "10e256"} = lex_hd("10e256")
    assert {:decimal_number, 1, "10E256"} = lex_hd("10E256")
    assert {:decimal_number, 1, "10e+256"} = lex_hd("10e+256")
    assert {:decimal_number, 1, "10e-256"} = lex_hd("10e-256")
    assert {:decimal_number, 1, "10E+256"} = lex_hd("10E+256")
    assert {:decimal_number, 1, "10E-256"} = lex_hd("10E-256")
    assert {:decimal_number, 1, "+10e-256"} = lex_hd("+10e-256")
    assert {:decimal_number, 1, "-10e+256"} = lex_hd("-10e+256")
    assert {:decimal_number, 1, "10e+2_56"} = lex_hd("10e+2_56")
    assert {:decimal_number, 1, "1_0e+2_56"} = lex_hd("1_0e+2_56")

    assert {:decimal_number, 1, "124.10e256"} = lex_hd("124.10e256")
    assert {:decimal_number, 1, "124.10e+256"} = lex_hd("124.10e+256")
    assert {:decimal_number, 1, "124.10e-256"} = lex_hd("124.10e-256")
    assert {:decimal_number, 1, "+124.10e-256"} = lex_hd("+124.10e-256")
    assert {:decimal_number, 1, "-124.10e-256"} = lex_hd("-124.10e-256")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} =
             Lexer.lex("124._578")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} =
             Lexer.lex("10e_256")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} =
             Lexer.lex("10e-_256")

    assert {:error, %SyntaxError{line: 1, message: "invalid number literal"}} =
             Lexer.lex("10e+_256")
  end

  test "correctly parses line comments" do
    assert {:line_comment, 1} = lex_hd("// my comment\nnode name=\"node name\"")

    assert {:line_comment, 1} = lex_at("node//key=\"value\" 10", 1)
  end

  test "correctly parses multiline comments" do
    assert {:multiline_comment, 1} = lex_hd("/* multiline comment */")

    {:ok, tokens} = Lexer.lex("node /*key=\"value\" 10*/ 20")

    assert [
             {:bare_identifier, 1, "node"},
             {:whitespace, 1, " "},
             {:multiline_comment, 1},
             {:whitespace, 1, " "},
             {:decimal_number, 1, "20"},
             :eof
           ] = tokens

    {:ok, tokens} = Lexer.lex("node {/*\n  /* nested */\n  /* comments */\n*/\n  child 20\n}")

    assert [
             {:bare_identifier, 1, "node"},
             {:whitespace, 1, " "},
             {:left_brace, 1},
             {:multiline_comment, 1},
             {:newline, 4, "\n"},
             {:whitespace, 5, " "},
             {:whitespace, 5, " "},
             {:bare_identifier, 5, "child"},
             {:whitespace, 5, " "},
             {:decimal_number, 5, "20"},
             {:newline, 5, "\n"},
             {:right_brace, 6},
             :eof
           ] = tokens

    assert {:error, %SyntaxError{line: 1, message: "unterminated multiline comment"}} =
             Lexer.lex("/* multiline comment ")

    assert {:error, %SyntaxError{line: 1, message: "unterminated multiline comment"}} =
             Lexer.lex("/* multiline /* comment */ ")
  end

  test "correctly parses node comments" do
    {:ok, tokens} = Lexer.lex("/-node 1")

    assert [
             {:node_comment, 1},
             {:bare_identifier, 1, "node"},
             {:whitespace, 1, " "},
             {:decimal_number, 1, "1"},
             :eof
           ] = tokens

    {:ok, tokens} = Lexer.lex("node /-1")

    assert [
             {:bare_identifier, 1, "node"},
             {:whitespace, 1, " "},
             {:node_comment, 1},
             {:decimal_number, 1, "1"},
             :eof
           ] = tokens

    {:ok, tokens} = Lexer.lex("node/-1")

    assert [
             {:bare_identifier, 1, "node"},
             {:node_comment, 1},
             {:decimal_number, 1, "1"},
             :eof
           ] = tokens
  end

  test "correctly parses line continuations" do
    assert {:continuation, 1} = lex_at("node \\\n10", 2)
    assert {:continuation, 1} = lex_at("node\\\n10", 1)
    assert {:continuation, 1} = lex_at("node \\ // comment\n  10", 2)
    assert {:continuation, 1} = lex_at("node \\//comment\n10", 2)
    assert {:continuation, 1} = lex_at("node\\//comment\n10", 1)
  end

  test "errors correctly report line number" do
    assert {:error, %SyntaxError{line: 2, message: "invalid character in unicode escape"}} =
             Lexer.lex("node_1\nnode_2 \"\\u{invalid unicode escape}\" \nnode_3")

    assert {:error, %SyntaxError{line: 5, message: "invalid number literal"}} =
             Lexer.lex("node_1 /*multi\nline\ncomment\n*/\nnode_2 0bnotnumber")

    assert {:error, %SyntaxError{line: 6, message: "invalid number literal"}} =
             Lexer.lex("node_1 \"\nmulti\nline\nstring\n\"\nnode_2 0bnotnumber")

    assert {:error, %SyntaxError{line: 7, message: "invalid number literal"}} =
             Lexer.lex("node_1 r\"\nmulti\nline\nraw\nstring\n\"\nnode_2 0bnotnumber")

    # \r\n counted as one newline within multiline comments and strings:

    assert {:error, %SyntaxError{line: 4, message: "unterminated string meets end of file"}} =
             Lexer.lex("node_1 /*\r\ncomment\r\n*/\r\n  node_2 \"string \\u{a0")

    assert {:error, %SyntaxError{line: 4, message: "unterminated string meets end of file"}} =
             Lexer.lex("node_1 \"\r\nstring\r\n\"\r\n node_2 \"string \\u{a0")

    assert {:error, %SyntaxError{line: 4, message: "unterminated string meets end of file"}} =
             Lexer.lex("node_1 r####\"\r\nstring\r\n\"####\r\n node_2 \"string \\u{a0")
  end
end
