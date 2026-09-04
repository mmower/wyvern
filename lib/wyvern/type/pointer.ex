defmodule Wyvern.Type.Pointer do
  @type t :: %__MODULE__{}
  defstruct []

  @spec new() :: __MODULE__.t()
  def new() do
    %__MODULE__{}
  end
end

defimpl Wyvern.IR, for: Wyvern.Type.Pointer do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Pointer{}, %IR.Context{} = ctx), do: {"ptr", ctx}
  def resolve_names(_, ctx), do: ctx
end
