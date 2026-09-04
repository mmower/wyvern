defmodule Wyvern.Value.Void do
  @type t :: %__MODULE__{}
  defstruct []

  def new() do
    %__MODULE__{}
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.Void do
  alias Wyvern.Value

  def to_ir(%Value.Void{}, ctx) do
    {"void", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end
