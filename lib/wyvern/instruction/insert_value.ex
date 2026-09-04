defmodule Wyvern.Instruction.InsertValue do
  @mnemonic "insertvalue"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          aggregate: Value.t(),
          value: Value.t(),
          index_list: [non_neg_integer()]
        }
  defstruct [:id, :dest, :aggregate, :value, :index_list]

  @spec new(Types.destination(), Value.t(), Value.t(), [non_neg_integer()]) ::
          __MODULE__.t()
  def new(dest, aggregate, value, index_list) when is_list(index_list) do
    validate_index_list(index_list)
    validate_type(aggregate, value, index_list)

    %__MODULE__{
      id: make_ref(),
      dest: dest,
      aggregate: aggregate,
      value: value,
      index_list: index_list
    }
  end

  defp validate_index_list(index_list) do
    if length(index_list) < 1, do: raise("insertvalue - must specify at least one index value!")

    unless Enum.all?(index_list, fn index -> is_integer(index) && index >= 0 end),
      do: raise("insertvalue - indexes must be non-negative integers!")
  end

  defp validate_type(aggregate, value, index_list) do
    field_type = Type.field_type(aggregate.type, index_list)

    if field_type != value.type,
      do: raise("insertvalue - field value disagrees with type value!")
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.InsertValue do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.InsertValue{
          id: id,
          aggregate: aggregate,
          value: value,
          index_list: index_list
        },
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {agg_str, ctx} = IR.to_ir(aggregate, ctx)
    {value_str, ctx} = IR.to_ir(value, ctx)

    index_str = Enum.join(index_list, ", ")

    {"%#{dest_str} = #{@for.mnemonic()} #{agg_str}, #{value_str}, #{index_str}", ctx}
  end

  def resolve_names(%Instruction.InsertValue{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.InsertValue do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.InsertValue{id: id, aggregate: aggregate}) do
    Handle.new(id, aggregate.type)
  end
end
