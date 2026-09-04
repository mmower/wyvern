defmodule Wyvern.Type.Void do
  @type t :: %__MODULE__{}
  defstruct []

  @spec new() :: __MODULE__.t()
  def new() do
    %__MODULE__{}
  end
end

defimpl Wyvern.IR, for: Wyvern.Type.Void do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Void{}, %IR.Context{} = ctx), do: {"void", ctx}
  def resolve_names(_, ctx), do: ctx
end
