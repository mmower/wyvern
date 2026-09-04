defmodule Wyvern.Value.Handle do
  alias Wyvern.Type

  @moduledoc """
  A Handle is used to refer to the value that is returned by
  an instruction and allow it to be passed as a value in the
  parameter of another instruction.

  In particular this unifies named and unnamed values where
  name resolution happens in a later step.
  """
  @type t :: %__MODULE__{
          id: reference(),
          type: Type.t()
        }
  defstruct [:id, :type]

  @spec new(reference(), Type.t()) :: __MODULE__.t()
  def new(id, type) when is_reference(id) do
    %__MODULE__{
      id: id,
      type: type
    }
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.Handle do
  alias Wyvern.IR
  alias Wyvern.IR.Helpers
  alias Wyvern.Value.Handle

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)

  @doc """
  Names have already been resolved.
  """
  def resolve_names(%Handle{}, %IR.Context{} = ctx) do
    ctx
  end
end

defimpl Wyvern.IROperand, for: Wyvern.Value.Handle do
  alias Wyvern.IR
  alias Wyvern.Value.Handle

  def to_operand(%Handle{id: id}, %IR.Context{} = ctx) do
    name = IR.Context.lookup_id(ctx, id)
    {"%#{name}", ctx}
  end
end
