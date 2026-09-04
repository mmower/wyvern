defmodule Wyvern.Type.Float do
  @type variant :: :half | :bfloat | :float | :double | :x86_fp80 | :fp128 | :ppc_fp128
  @type t :: %__MODULE__{
          variant: variant()
        }
  defstruct [:variant]

  @spec new(variant()) :: __MODULE__.t()
  def new(variant) do
    %__MODULE__{variant: variant}
  end
end

defimpl Wyvern.IR, for: Wyvern.Type.Float do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Float{variant: v}, %IR.Context{} = ctx), do: {"#{v}", ctx}
  def resolve_names(_, ctx), do: ctx
end
