defmodule Wyvern.Value.GlobalRef do
  alias Wyvern.Type
  alias Wyvern.Identifier

  @type t :: %__MODULE__{
          type: Type.t(),
          name: String.t()
        }
  defstruct [:type, :name]

  @spec new(String.t()) :: __MODULE__.t()
  def new(name) when is_binary(name) do
    %__MODULE__{type: Type.ptr(), name: Identifier.legal_identifier(name)}
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.GlobalRef do
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IROperand, for: Wyvern.Value.GlobalRef do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.GlobalRef{name: name}, %IR.Context{} = ctx) do
    {"@#{name}", ctx}
  end
end
