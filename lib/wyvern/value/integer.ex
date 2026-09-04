defmodule Wyvern.Value.Integer do
  alias Wyvern.Type

  @type t :: %__MODULE__{
          type: Type.Integer.t(),
          value: integer()
        }
  defstruct [:type, :value]

  @spec new(Type.Integer.t(), integer()) :: __MODULE__.t()
  def new(type, value) do
    %__MODULE__{type: type, value: value}
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.Integer do
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IROperand, for: Wyvern.Value.Integer do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.Integer{value: value}, %IR.Context{} = ctx) do
    {"#{value}", ctx}
  end
end
