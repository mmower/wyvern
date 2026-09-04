defmodule Wyvern.Type.NamedStruct do
  alias Wyvern.Identifier

  alias Wyvern.Identifier

  @type field_list :: [Wyvern.Type.t()]

  @type t :: %__MODULE__{
          name: String.t(),
          fields: field_list(),
          packed: boolean()
        }
  defstruct [:name, :fields, :packed]

  @spec new(String.t(), field_list(), keyword()) :: __MODULE__.t()
  def new(name, fields, opts \\ []) do
    packed = Keyword.get(opts, :packed, false)

    %__MODULE__{
      name: Identifier.legal_identifier(name),
      fields: fields,
      packed: packed
    }
  end
end

defimpl Wyvern.IR, for: Wyvern.Type.NamedStruct do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.NamedStruct{name: name}, %IR.Context{} = ctx) do
    {"%#{name}", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end
