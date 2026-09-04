defmodule Wyvern.Instruction.Select do
  @mnemonic "select"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          cond: Value.t(),
          if_true: Value.t(),
          if_false: Value.t()
        }
  defstruct [:id, :dest, :cond, :if_true, :if_false]

  def new(dest, cond, if_true, if_false) do
    unless cond.type == Type.i1(), do: raise("select - condition must be typed i1!")

    unless if_true.type == if_false.type,
      do: raise("select - if_true/if_false values must share the same type!")

    %__MODULE__{
      id: make_ref(),
      dest: dest,
      cond: cond,
      if_true: if_true,
      if_false: if_false
    }
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Select do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.Select{id: id, cond: cond, if_true: if_true, if_false: if_false},
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {cond_str, ctx} = IR.to_ir(cond, ctx)
    {if_true_str, ctx} = IR.to_ir(if_true, ctx)
    {if_false_str, ctx} = IR.to_ir(if_false, ctx)
    {"%#{dest_str} = #{@for.mnemonic()} #{cond_str}, #{if_true_str}, #{if_false_str}", ctx}
  end

  def resolve_names(%Instruction.Select{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Select do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Select{id: id, if_true: if_true}) do
    Handle.new(id, if_true.type)
  end
end
