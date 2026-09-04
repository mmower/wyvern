defmodule Wyvern.Type.Array do
  alias Wyvern.Type

  alias Wyvern.Type

  @type t :: %__MODULE__{
          type: Wyvern.Type.t(),
          len: non_neg_integer()
        }
  defstruct [:type, :len]

  @spec new(Type.t(), non_neg_integer()) :: __MODULE__.t()
  def new(type, len) do
    %__MODULE__{type: type, len: len}
  end
end

defimpl Wyvern.IR, for: Wyvern.Type.Array do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Array{type: type, len: len}, %IR.Context{} = ctx) do
    {type_s, ctx_2} = Wyvern.IR.to_ir(type, ctx)
    {"[#{len} x #{type_s}]", ctx_2}
  end

  def resolve_names(_, ctx), do: ctx
end
