defmodule ExKdl.LexerTest do
  use ExUnit.Case, async: true

  alias ExKdl.Chars
  alias ExKdl.LexerRedux, as: Lexer

  alias ExKdl.DecodeError

  defp lex_at(src, at) do
    {:ok, tokens} = Lexer.lex(src)
    tokens |> Enum.at(at)
  end

  defp lex_hd(src) do
    lex_at(src, 0)
  end

  test "correctly parses BOM" do
    assert {:bom, 1, 0} = lex_hd("\u{FEFF}")
  end

  test "correctly parses null" do
    assert {:null, 1, 0} = lex_hd("null")
  end

  test "correctly parses booleans" do
    assert {:boolean, 1, 0, false} = lex_hd("false")
    assert {:boolean, 1, 0, true} = lex_hd("true")
  end

  test "correctly parses newlines" do
    for char <- Chars.newline_chars() do
      byte_range = 0..Chars.get_char_byte_length(char)
      assert {:newline, 1, ^byte_range} = lex_hd(<<char::utf8>>)
    end

    # \r\n considered one newline ("bar" should be on line two not three)
    {:ok, tokens} = Lexer.lex("foo\r\nbar")

    assert [
             {:bare_identifier, 1, 0, "foo"},
             {:newline, 1, 3..5},
             {:bare_identifier, 2, 5, "bar"},
             {:eof}
           ] = tokens

    # Groups consecutive newlines into one token
    assert {:newline, 1, 0..4} = lex_hd("\n\n\n\n")
  end

  test "correctly parses whitespace" do
    for char <- Chars.whitespace_chars() do
      byte_range = 0..Chars.get_char_byte_length(char)
      assert {:whitespace, 1, ^byte_range} = lex_hd(<<char::utf8>>)
    end

    # Groups consecutive spaces into one token
    assert {:whitespace, 1, 0..6} = lex_hd("    \t ")
  end

  test "correctly parses bare identifiers" do
    assert {:bare_identifier, 1, 0, "foo"} = lex_hd("foo")
    assert {:bare_identifier, 1, 0, "foo_bar"} = lex_hd("foo_bar")
    assert {:bare_identifier, 1, 0, "foo-bar"} = lex_hd("foo-bar")
    assert {:bare_identifier, 1, 0, "foo.bar"} = lex_hd("foo.bar")
    assert {:bare_identifier, 1, 0, "foo123"} = lex_hd("foo123")

    assert {:bare_identifier, 1, 0, "rawstring"} = lex_hd("rawstring")
    assert {:bare_identifier, 1, 0, "r###notarawstring"} = lex_hd("r###notarawstring")

    legal_bare_ident = "foo123~!@#$%^&*.:'|?+"
    assert {:bare_identifier, 1, 0, ^legal_bare_ident} = lex_hd(legal_bare_ident)
  end

  test "correctly parses escaped strings" do
    assert {:string, 1, 0..2, ""} = lex_hd("\"\"")
    assert {:string, 1, 0..13, "hello world"} = lex_hd("\"hello world\"")
    assert {:string, 1, 0..13, "hello\nworld"} = lex_hd("\"hello\nworld\"")
    assert {:string, 1, 0..14, "hello\nworld"} = lex_hd("\"hello\\nworld\"")
    assert {:string, 1, 0..14, "hello\tworld"} = lex_hd("\"hello\\tworld\"")
    assert {:string, 1, 0..18, "hello\t\"world\""} = lex_hd("\"hello\\t\\\"world\\\"\"")

    assert {:string, 1, 0..4, "\""} = lex_hd("\"\\\"\"")

    assert {:error, %DecodeError{line: 1, message: "invalid escape in string"}} =
             Lexer.lex("\"hello\\kworld\"")

    assert {:string, 1, 0..8, "\n"} = lex_hd("\"\\u{0a}\"")
    assert {:string, 1, 0..10, "ü"} = lex_hd("\"\\u{00FC}\"")
    assert {:string, 1, 0..12, "􏿿"} = lex_hd("\"\\u{10FFFF}\"")

    assert {:string, 1, 0..22, "order an über"} = lex_hd("\"order an \\u{00FC}ber\"")
    assert {:string, 1, 0..19, "über über"} = lex_hd("\"über \\u{00FC}ber\"")
    assert {:string, 1, 0..19, "über über"} = lex_hd("\"\\u{00FC}ber über\"")

    assert {:error, %DecodeError{line: 1, message: "invalid character in unicode escape"}} =
             Lexer.lex("\"\\u{tty}\"")

    assert {:error,
            %DecodeError{line: 1, message: "unicode escape must have at least 1 hex digit"}} =
             Lexer.lex("\"\\u{}\"")

    assert {:error, %DecodeError{line: 1, message: "unterminated unicode escape"}} =
             Lexer.lex("\"\\u{0a\"")

    assert {:error, %DecodeError{line: 1, message: "unterminated unicode escape"}} =
             Lexer.lex("\"\\u{\"")

    assert {:error, %DecodeError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node \"name")

    assert {:error, %DecodeError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node \"\\u{")
  end

  test "correctly parses raw strings" do
    assert {:string, 1, 0..14, "hello world"} = lex_hd("r\"hello world\"")
    assert {:string, 1, 0..15, "hello\\\\nworld"} = lex_hd("r\"hello\\nworld\"")
    assert {:string, 1, 0..15, "hello\\\\tworld"} = lex_hd("r\"hello\\tworld\"")
    assert {:string, 1, 0..14, "hello\nworld"} = lex_hd("r\"hello\nworld\"")
    assert {:string, 1, 0..14, "hello\tworld"} = lex_hd("r\"hello\tworld\"")

    assert {:string, 1, 0..16, "hello world"} = lex_hd("r#\"hello world\"#")
    assert {:string, 1, 0..17, "hello\\\\nworld"} = lex_hd("r#\"hello\\nworld\"#")
    assert {:string, 1, 0..17, "hello\\\\tworld"} = lex_hd("r#\"hello\\tworld\"#")
    assert {:string, 1, 0..16, "hello\nworld"} = lex_hd("r#\"hello\nworld\"#")
    assert {:string, 1, 0..16, "hello\tworld"} = lex_hd("r#\"hello\tworld\"#")
    assert {:string, 1, 0..19, "hello\\\\t\"world\""} = lex_hd("r#\"hello\\t\"world\"\"#")

    assert {:string, 1, 0..18, "hello world"} = lex_hd("r##\"hello world\"##")
    assert {:string, 1, 0..21, "hello \"# world"} = lex_hd("r##\"hello \"# world\"##")
    assert {:string, 1, 0..22, "hello world"} = lex_hd("r####\"hello world\"####")

    assert {:string, 1, 0..29, "hello \" \"### world"} =
             lex_hd("r####\"hello \" \"### world\"####")

    assert {:error, %DecodeError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node r\"name")

    assert {:error, %DecodeError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node r#\"name")

    assert {:error, %DecodeError{line: 1, message: "unterminated string meets end of file"}} =
             Lexer.lex("node r##\"name\"# 10")
  end

  test "correctly parses binary" do
    tests = [
      {"0b0", 0..3, Decimal.new(0)},
      {"0b1", 0..3, Decimal.new(1)},
      {"0b010011", 0..8, Decimal.new(19)},
      {"+0b010011", 0..9, Decimal.new(19)},
      {"-0b010011", 0..9, Decimal.new(-19)},
      {"0b010_011", 0..9, Decimal.new(19)},
      {"+0b010_011", 0..10, Decimal.new(19)},
      {"-0b010_011", 0..10, Decimal.new(-19)},
      {"0b010___011", 0..11, Decimal.new(19)},
      {"0b0_1_0_0_1_1", 0..13, Decimal.new(19)},
      {"0b010011_", 0..9, Decimal.new(19)},
      {"0b010011___", 0..11, Decimal.new(19)}
    ]

    for {input, range, expected_decimal} <- tests do
      assert {:number, 1, ^range, ^expected_decimal} = lex_hd(input)
    end

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("0b_010011")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("0b")
    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("0b5")
    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("0ba")
  end

  test "correctly parses octal" do
    tests = [
      {"0o0", 0..3, Decimal.new(0)},
      {"0o7", 0..3, Decimal.new(7)},
      {"0o312467", 0..8, Decimal.new(103_735)},
      {"+0o312467", 0..9, Decimal.new(103_735)},
      {"-0o312467", 0..9, Decimal.new(-103_735)},
      {"0o312_467", 0..9, Decimal.new(103_735)},
      {"+0o312_467", 0..10, Decimal.new(103_735)},
      {"-0o312_467", 0..10, Decimal.new(-103_735)},
      {"0o312___467", 0..11, Decimal.new(103_735)},
      {"0o3_1_2_4_6_7", 0..13, Decimal.new(103_735)},
      {"0o312467_", 0..9, Decimal.new(103_735)},
      {"0o312467___", 0..11, Decimal.new(103_735)}
    ]

    for {input, range, expected_decimal} <- tests do
      assert {:number, 1, ^range, ^expected_decimal} = lex_hd(input)
    end

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("0o_312467")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("0o")
    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("0o8")
    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("0oa")
  end

  test "correctly parses hexadecimal" do
    tests = [
      {"0x0", 0..3, Decimal.new(0)},
      {"0xF", 0..3, Decimal.new(15)},
      {"0x0A93BD8", 0..9, Decimal.new(11_090_904)},
      {"0x0a93bd8", 0..9, Decimal.new(11_090_904)},
      {"0x0A93bd8", 0..9, Decimal.new(11_090_904)},
      {"+0x0A93BD8", 0..10, Decimal.new(11_090_904)},
      {"-0x0A93BD8", 0..10, Decimal.new(-11_090_904)},
      {"0x0A93_BD8", 0..10, Decimal.new(11_090_904)},
      {"+0x0A93_BD8", 0..11, Decimal.new(11_090_904)},
      {"-0x0A93_BD8", 0..11, Decimal.new(-11_090_904)},
      {"0x0A93___BD8", 0..12, Decimal.new(11_090_904)},
      {"0x0_A_9_3_B_D_8", 0..15, Decimal.new(11_090_904)},
      {"0x0A93bd8_", 0..10, Decimal.new(11_090_904)},
      {"0x0A93bd8___", 0..12, Decimal.new(11_090_904)}
    ]

    for {input, range, expected_decimal} <- tests do
      assert {:number, 1, ^range, ^expected_decimal} = lex_hd(input)
    end

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("0x_0A93bd8")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("0x")
    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("0xG")
    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("0xg")
  end

  test "correctly parses decimal" do
    tests = [
      {"0", 0..1, Decimal.new(0)},
      {"9", 0..1, Decimal.new(9)},
      {"124578", 0..6, Decimal.new(124_578)},
      {"+124578", 0..7, Decimal.new(124_578)},
      {"-124578", 0..7, Decimal.new(-124_578)},
      {"124_578", 0..7, Decimal.new(124_578)},
      {"+124_578", 0..8, Decimal.new(124_578)},
      {"-124_578", 0..8, Decimal.new(-124_578)},
      {"124___578", 0..9, Decimal.new(124_578)},
      {"1_2_4_5_7_8", 0..11, Decimal.new(124_578)},
      {"124578_", 0..7, Decimal.new(124_578)},
      {"124578___", 0..9, Decimal.new(124_578)},
      {"124.578", 0..7, Decimal.new("124.578")},
      {"+124.578", 0..8, Decimal.new("124.578")},
      {"-124.578", 0..8, Decimal.new("-124.578")},
      {"12_4.57_8", 0..9, Decimal.new("124.578")},
      {"124_.57__8_", 0..11, Decimal.new("124.578")},
      {"10e256", 0..6, Decimal.new("1.0E257")},
      {"10E256", 0..6, Decimal.new("1.0E257")},
      {"10e+256", 0..7, Decimal.new("1.0E257")},
      {"10e-256", 0..7, Decimal.new("1.0E-255")},
      {"10E+256", 0..7, Decimal.new("1.0E257")},
      {"10E-256", 0..7, Decimal.new("1.0E-255")},
      {"+10e-256", 0..8, Decimal.new("1.0E-255")},
      {"-10e+256", 0..8, Decimal.new("-1.0E257")},
      {"10e+2_56", 0..8, Decimal.new("1.0E257")},
      {"1_0e+2_56", 0..9, Decimal.new("1.0E257")},
      {"124.10e256", 0..10, Decimal.new("1.2410E258")},
      {"124.10e+256", 0..11, Decimal.new("1.2410E258")},
      {"124.10e-256", 0..11, Decimal.new("1.2410E-254")},
      {"+124.10e-256", 0..12, Decimal.new("1.2410E-254")},
      {"-124.10e-256", 0..12, Decimal.new("-1.2410E-254")}
    ]

    for {input, range, expected_decimal} <- tests do
      assert {:number, 1, ^range, ^expected_decimal} = lex_hd(input)
    end

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("124._578")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("10e_256")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("10e-_256")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("10e+_256")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("1.")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("1.0e")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("1.0e+")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("1.0e-")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} = Lexer.lex("1.0E")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("1.0E+")

    assert {:error, %DecodeError{line: 1, message: "invalid numeric literal"}} =
             Lexer.lex("1.0E-")
  end

  test "correctly parses line comments" do
    assert {:line_comment, 1, 0..13} = lex_hd("// my comment\nnode name=\"node name\"")

    assert {:line_comment, 1, 4..20} = lex_at("node//key=\"value\" 10", 1)
  end

  # test "correctly parses multiline comments" do
  #   assert {:multiline_comment, 1} = lex_hd("/* multiline comment */")

  #   {:ok, tokens} = Lexer.lex("node /*key=\"value\" 10*/ 20")

  #   assert [
  #            {:bare_identifier, 1, "node"},
  #            {:whitespace, 1, " "},
  #            {:multiline_comment, 1},
  #            {:whitespace, 1, " "},
  #            {:number, 1, %Decimal{coef: 20}},
  #            {:eof}
  #          ] = tokens

  #   {:ok, tokens} = Lexer.lex("node {/*\n  /* nested */\n  /* comments */\n*/\n  child 20\n}")

  #   assert [
  #            {:bare_identifier, 1, "node"},
  #            {:whitespace, 1, " "},
  #            {:left_brace, 1},
  #            {:multiline_comment, 1},
  #            {:newline, 4, "\n"},
  #            {:whitespace, 5, " "},
  #            {:whitespace, 5, " "},
  #            {:bare_identifier, 5, "child"},
  #            {:whitespace, 5, " "},
  #            {:number, 5, %Decimal{coef: 20}},
  #            {:newline, 5, "\n"},
  #            {:right_brace, 6},
  #            {:eof}
  #          ] = tokens

  #   assert {:error, %DecodeError{line: 1, message: "unterminated multiline comment"}} =
  #            Lexer.lex("/* multiline comment ")

  #   assert {:error, %DecodeError{line: 1, message: "unterminated multiline comment"}} =
  #            Lexer.lex("/* multiline /* comment */ ")
  # end

  test "correctly parses node comments" do
    {:ok, tokens} = Lexer.lex("/-node 1")

    assert [
             {:slashdash, 1, 0},
             {:bare_identifier, 1, 2, "node"},
             {:whitespace, 1, 6..7},
             {:number, 1, 7..8, %Decimal{coef: 1}},
             {:eof}
           ] = tokens

    {:ok, tokens} = Lexer.lex("node /-1")

    assert [
             {:bare_identifier, 1, 0, "node"},
             {:whitespace, 1, 4..5},
             {:slashdash, 1, 5},
             {:number, 1, 7..8, %Decimal{coef: 1}},
             {:eof}
           ] = tokens

    {:ok, tokens} = Lexer.lex("node/-1")

    assert [
             {:bare_identifier, 1, 0, "node"},
             {:slashdash, 1, 4},
             {:number, 1, 6..7, %Decimal{coef: 1}},
             {:eof}
           ] = tokens
  end

  test "correctly parses line continuations" do
    assert {:continuation, 1, 5} = lex_at("node \\\n10", 2)
    assert {:continuation, 1, 4} = lex_at("node\\\n10", 1)
    assert {:continuation, 1, 5} = lex_at("node \\ // comment\n  10", 2)
    assert {:continuation, 1, 5} = lex_at("node \\//comment\n10", 2)
    assert {:continuation, 1, 4} = lex_at("node\\//comment\n10", 1)
  end

  # test "errors correctly report line number" do
  #   assert {:error, %DecodeError{line: 2, message: "invalid character in unicode escape"}} =
  #            Lexer.lex("node_1\nnode_2 \"\\u{invalid unicode escape}\" \nnode_3")

  #   assert {:error, %DecodeError{line: 5, message: "invalid numeric literal"}} =
  #            Lexer.lex("node_1 /*multi\nline\ncomment\n*/\nnode_2 0bnotnumber")

  #   assert {:error, %DecodeError{line: 6, message: "invalid numeric literal"}} =
  #            Lexer.lex("node_1 \"\nmulti\nline\nstring\n\"\nnode_2 0bnotnumber")

  #   assert {:error, %DecodeError{line: 7, message: "invalid numeric literal"}} =
  #            Lexer.lex("node_1 r\"\nmulti\nline\nraw\nstring\n\"\nnode_2 0bnotnumber")

  #   # \r\n counted as one newline within multiline comments and strings:

  #   assert {:error, %DecodeError{line: 4, message: "unterminated string meets end of file"}} =
  #            Lexer.lex("node_1 /*\r\ncomment\r\n*/\r\n  node_2 \"string \\u{a0")

  #   assert {:error, %DecodeError{line: 4, message: "unterminated string meets end of file"}} =
  #            Lexer.lex("node_1 \"\r\nstring\r\n\"\r\n node_2 \"string \\u{a0")

  #   assert {:error, %DecodeError{line: 4, message: "unterminated string meets end of file"}} =
  #            Lexer.lex("node_1 r####\"\r\nstring\r\n\"####\r\n node_2 \"string \\u{a0")
  # end
end
