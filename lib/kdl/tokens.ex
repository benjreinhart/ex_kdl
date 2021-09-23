defmodule Kdl.Tokens do
  defmodule Eof do
    defstruct []
  end

  defmodule Semicolon do
    defstruct []
  end

  defmodule LeftBrace do
    defstruct []
  end

  defmodule RightBrace do
    defstruct []
  end

  defmodule LeftParen do
    defstruct []
  end

  defmodule RightParen do
    defstruct []
  end

  defmodule Equals do
    defstruct []
  end

  defmodule Null do
    defstruct []
  end

  defmodule Continuation do
    defstruct []
  end

  defmodule NodeComment do
    defstruct []
  end

  defmodule Newline do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule Whitespace do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule Boolean do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule BinaryNumber do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule OctalNumber do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule DecimalNumber do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule HexadecimalNumber do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule String do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule RawString do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule BareIdentifier do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule LineComment do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule MultilineComment do
    @enforce_keys [:value]
    defstruct [:value]
  end
end
