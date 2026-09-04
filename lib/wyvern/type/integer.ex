defmodule Wyvern.Type.Integer do
  @type width :: pos_integer()
  @type t :: %__MODULE__{
          width: width()
        }
  defstruct [:width]

  @spec new(pos_integer()) :: __MODULE__.t()
  def new(width) do
    %__MODULE__{width: width}
  end
end

defimpl Wyvern.IR, for: Wyvern.Type.Integer do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Integer{width: w}, %IR.Context{} = ctx), do: {"i#{w}", ctx}
  def resolve_names(_, ctx), do: ctx
end
