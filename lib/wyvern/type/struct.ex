defmodule Wyvern.Type.Struct do
  @type field_list :: [Wyvern.Type.t()]

  @type t :: %__MODULE__{
          fields: field_list(),
          packed: boolean()
        }
  defstruct fields: [], packed: false

  @spec new(field_list(), keyword()) :: __MODULE__.t()
  def new(fields, opts \\ []) when is_list(fields) and is_list(opts) do
    packed = Keyword.get(opts, :packed, false)
    %__MODULE__{fields: fields, packed: packed}
  end
end

defimpl Wyvern.IR, for: Wyvern.Type.Struct do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Struct{fields: fields, packed: packed}, %IR.Context{} = ctx) do
    fields
    |> Enum.map_reduce(ctx, &IR.to_ir/2)
    |> join_fields(packed)
  end

  defp join_fields({fields, ctx}, false) do
    {"{" <> Enum.join(fields, ", ") <> "}", ctx}
  end

  defp join_fields({fields, ctx}, true) do
    {"<{" <> Enum.join(fields, ", ") <> "}>", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end
