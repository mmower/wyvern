defmodule Wyvern.Label do
  @moduledoc """
  A Label is an id and an associated name that can be used to mark
  things like basic blocks so that they have an id assigned ahead of
  time (this makes forward references a possibility).
  """
  @type name :: String.t() | nil

  @type t :: %__MODULE__{
          id: reference(),
          name: name()
        }
  defstruct [:id, :name]

  @spec new(name()) :: __MODULE__.t()
  def new(name \\ nil) when is_nil(name) or is_binary(name) do
    %__MODULE__{
      id: make_ref(),
      name: name
    }
  end
end

defimpl Wyvern.IR, for: Wyvern.Label do
  alias Wyvern.IR
  alias Wyvern.Label

  def to_ir(%Label{}, _ctx) do
    raise "Unsupported: IR.to_ir not supported on Label!"
  end

  def resolve_names(%Label{} = label, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, label)
  end
end
