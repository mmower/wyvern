defmodule Wyvern.Value.Poison do
  alias Wyvern.Type

  import Wyvern.Type.Guards

  @type t :: %__MODULE__{
          type: Type.t()
        }
  defstruct [:type]

  @spec new(Type.t()) :: __MODULE__.t()
  def new(type) when is_llvm_type(type) do
    %__MODULE__{type: type}
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.Poison do
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IROperand, for: Wyvern.Value.Poison do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.Poison{}, %IR.Context{} = ctx) do
    {"poison", ctx}
  end
end
