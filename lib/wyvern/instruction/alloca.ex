defmodule Wyvern.Instruction.Alloca do
  @mnemonic "alloca"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type count :: Value.t() | pos_integer()
  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          type: Type.t(),
          count: count()
        }
  defstruct [:id, :dest, :type, :count]

  @spec new(Types.destination(), Type.t(), count()) :: __MODULE__.t()

  def new(dest, type, count) when is_integer(count) do
    %__MODULE__{
      id: make_ref(),
      dest: dest,
      type: type,
      count: count
    }
  end

  def new(dest, type, %{type: %Type.Integer{}} = count) do
    %__MODULE__{
      id: make_ref(),
      dest: dest,
      type: type,
      count: count
    }
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Alloca do
  alias Wyvern.IR
  alias Wyvern.Type
  alias Wyvern.Instruction

  def to_ir(%Instruction.Alloca{id: id, type: type, count: count}, %IR.Context{} = ctx)
      when is_integer(count) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(type, ctx)

    if count > 1 do
      count_type = Type.min_width_type(count)
      {count_type_str, ctx_2} = IR.to_ir(count_type, ctx_1)
      {"%#{dest_str} = #{@for.mnemonic()} #{type_str}, #{count_type_str} #{count}", ctx_2}
    else
      {"%#{dest_str} = #{@for.mnemonic()} #{type_str}", ctx_1}
    end
  end

  def to_ir(
        %Instruction.Alloca{id: id, type: type, count: %{type: %Type.Integer{}} = count},
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(type, ctx)
    {count_str, ctx_2} = IR.to_ir(count, ctx_1)
    {"%#{dest_str} = #{@for.mnemonic()} #{type_str}, #{count_str}", ctx_2}
  end

  def resolve_names(%Instruction.Alloca{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Alloca do
  def to_handle(instruction), do: Wyvern.ToHandle.Helpers.as_ptr(instruction)
end
