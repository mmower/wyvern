defmodule Wyvern.Instruction.Call do
  @mnemonic "call"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          fn_type: Type.Function.t(),
          fn_ref: Value.t(),
          args: [Value.t()]
        }
  defstruct [:id, :dest, :fn_type, :fn_ref, :args]

  @spec new(Types.destination(), Type.Function.t(), Value.t(), [Value.t()]) :: __MODULE__.t()
  def new(dest, fn_type, fn_ref, args) do
    if !is_nil(dest) && Type.void?(fn_type.ret_type),
      do: raise("Unsupported: cannot return from a void function!")

    unless Type.ptr?(fn_ref.type), do: raise("Unsupported: attempt to call non-pointer target!")

    validate_args!(fn_type, args)

    %__MODULE__{
      id: make_ref(),
      dest: dest,
      fn_type: fn_type,
      fn_ref: fn_ref,
      args: args
    }
  end

  def validate_args!(fn_type, args) do
    if !fn_type.var_args && length(fn_type.params) != length(args),
      do: raise("Attempt to call function with wrong number of arguments!")

    if fn_type.var_args && length(args) < length(fn_type.params),
      do: raise("Attempt to call function with insufficient arguments!")

    arg_types = Enum.map(args, & &1.type)
    mappings = Enum.zip(arg_types, fn_type.params)

    if Enum.filter(mappings, fn {arg_type, param} -> arg_type != param end) != [] do
      raise "Attempt to call function with different argument types!"
    end
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Call do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction
  alias Wyvern.Type

  @doc """
  <result> = [tail | musttail | notail ] call [fast-math flags] [cconv] [ret attrs] [addrspace(<num>)]
           <ty>|<fnty> <fnptrval>(<function args>) [fn attrs] [ operand bundles ]

  """
  def to_ir(
        %Wyvern.Instruction.Call{id: id, fn_type: fn_type, fn_ref: fn_ref, args: args},
        %IR.Context{} = ctx
      ) do
    dest_str = resolve_dest(id, fn_type, ctx)
    {ret_type_str, ctx_1} = IR.to_ir(fn_type.ret_type, ctx)
    {fn_str, ctx_2} = IROperand.to_operand(fn_ref, ctx_1)
    {args_ir, ctx_3} = Enum.map_reduce(args, ctx_2, &IR.to_ir/2)
    args_str = Enum.join(args_ir, ", ")
    {args_shape, ctx_4} = args_shape(fn_type, ctx_3)

    if dest_str == nil do
      {"#{@for.mnemonic()} #{ret_type_str} #{args_shape}#{fn_str}(#{args_str})", ctx_4}
    else
      {"%#{dest_str} = #{@for.mnemonic()} #{ret_type_str} #{args_shape}#{fn_str}(#{args_str})",
       ctx_4}
    end
  end

  defp args_shape(%Type.Function{var_args: false}, ctx) do
    {"", ctx}
  end

  defp args_shape(%Type.Function{params: params}, ctx) do
    {param_types, ctx_1} =
      Enum.map_reduce(params, ctx, &IR.to_ir/2)

    {"(" <> Enum.join(param_types, ", ") <> ", ...) ", ctx_1}
  end

  defp resolve_dest(id, fn_type, ctx) do
    if Type.void?(fn_type.ret_type) do
      nil
    else
      IR.Context.lookup_id(ctx, id)
    end
  end

  def resolve_names(
        %Instruction.Call{id: id, dest: dest, fn_type: fn_type},
        %IR.Context{} = ctx
      ) do
    if Type.void?(fn_type.ret_type) do
      ctx
    else
      IR.Context.map_id_to_name(ctx, id, dest)
    end
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Call do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Call{fn_type: %{ret_type: %Wyvern.Type.Void{}}}) do
    raise "ToHandle not supported in void call!"
  end

  def to_handle(%Wyvern.Instruction.Call{id: id, fn_type: %{ret_type: ret_type}}) do
    Handle.new(id, ret_type)
  end
end
