defmodule Wyvern.Value.Struct do
  alias Wyvern.Type
  alias Wyvern.Value

  alias Wyvern.Value

  @type t :: %__MODULE__{
          type: Type.t(),
          fields: [Value.t()]
        }
  defstruct [:type, :fields]

  @spec new([Value.t()], keyword()) :: __MODULE__.t()
  def new(fields, opts) when is_list(opts) do
    if Enum.any?(fields, &Value.dynamic_value?/1),
      do: raise("Unsupported dynamic value in struct!")

    packed = Keyword.get(opts, :packed, false)

    field_types = Enum.map(fields, & &1.type)
    type = Wyvern.Type.struct(field_types, packed: packed)

    %__MODULE__{
      type: type,
      fields: fields
    }
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.Struct do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.Struct{type: type, fields: fields}, %IR.Context{} = ctx) do
    {type_str, ctx} = IR.to_ir(type, ctx)
    {fields_ir, ctx} = Enum.map_reduce(fields, ctx, &IR.to_ir/2)
    fields_str = Enum.join(fields_ir, ", ")

    value_str =
      if type.packed do
        "<{" <> fields_str <> "}>"
      else
        "{" <> fields_str <> "}"
      end

    {"#{type_str} #{value_str}", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end
