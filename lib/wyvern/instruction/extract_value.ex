defmodule Wyvern.Instruction.ExtractValue do
  @mnemonic "extractvalue"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          aggregate: Value.t(),
          index_list: [non_neg_integer()],
          value_type: Type.t()
        }
  defstruct [:id, :dest, :aggregate, :index_list, :value_type]

  def new(dest, aggregate, index_list) do
    validate_index_list(index_list)
    value_type = Type.field_type(aggregate.type, index_list)

    %__MODULE__{
      id: make_ref(),
      dest: dest,
      aggregate: aggregate,
      index_list: index_list,
      value_type: value_type
    }
  end

  defp validate_index_list(index_list) do
    if length(index_list) < 1,
      do: raise("extractvalue - must specify at least one index value!")

    unless Enum.all?(index_list, fn index -> is_integer(index) && index >= 0 end),
      do: raise("extractvalue - indexes must be non-negative integers!")
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.ExtractValue do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.ExtractValue{id: id, aggregate: aggregate, index_list: index_list},
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {agg_str, ctx} = IR.to_ir(aggregate, ctx)
    index_str = Enum.join(index_list, ", ")
    {"%#{dest_str} = #{@for.mnemonic()} #{agg_str}, #{index_str}", ctx}
  end

  def resolve_names(%Instruction.ExtractValue{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.ExtractValue do
  alias Wyvern.Value.Handle
  alias Wyvern.Instruction

  def to_handle(%Instruction.ExtractValue{id: id, value_type: value_type}) do
    Handle.new(id, value_type)
  end
end
