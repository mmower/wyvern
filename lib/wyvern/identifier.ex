defmodule Wyvern.Identifier do
  # Legal identifiers begin with a letter, _, . or $
  # or are a bare number like 0, 23, 123
  # Everything else gets escaped \"<id>\"
  @identifier_re ~r/^([A-Za-z_\.\$][A-Za-z0-9_\.\$]*|[0-9]+)$/

  def legal_identifier(identifier) when is_binary(identifier) do
    if Regex.match?(@identifier_re, identifier) do
      identifier
    else
      escape_identifier(identifier)
    end
  end

  @illegal_char_re ~r/[\x00-\x1F\x7F-\xFF]/u

  def escape_identifier(identifier) do
    escaped =
      identifier
      |> String.replace("\\", "\\5C")
      |> String.replace("\"", "\\22")
      |> then(fn s ->
        Regex.replace(@illegal_char_re, s, fn <<c::utf8>> ->
          "\\" <> String.pad_leading(Elixir.Integer.to_string(c, 16), 2, "0")
        end)
      end)

    ~s("#{escaped}")
  end
end
