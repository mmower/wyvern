defmodule Wyvern.Value.Array do
  alias Wyvern.Type
  alias Wyvern.Value

  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          type: Type.t(),
          elems: [Value.t()]
        }
  defstruct [:type, :elems]

  @spec new(Type.t(), [Value.t()]) :: __MODULE__.t()
  def new(type, elems) do
    validate_type(elems, type)
    validate_static(elems)

    %__MODULE__{
      type: Type.array(type, Enum.count(elems)),
      elems: elems
    }
  end

  defp validate_type([], _), do: true

  defp validate_type(elems, type) do
    unless Enum.all?(elems, &(&1.type == type)), do: raise("array element does not match type!")
  end

  defp validate_static(elems) do
    if Enum.any?(elems, &Value.dynamic_value?/1),
      do: raise("Unsupported dynamic value in array!")
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.Array do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.Array{type: type, elems: elems}, %IR.Context{} = ctx) do
    {type_str, ctx} = IR.to_ir(type, ctx)
    {elems_ir, ctx} = Enum.map_reduce(elems, ctx, &IR.to_ir/2)
    elems_str = Enum.join(elems_ir, ", ")
    {"#{type_str} [#{elems_str}]", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end
