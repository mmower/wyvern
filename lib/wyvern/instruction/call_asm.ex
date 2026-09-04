defmodule Wyvern.Instruction.CallASM do
  @mnemonic "call"
  alias Wyvern.Instruction.Call
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @moduledoc """
  The CallASM module is a variant of Call that is used for inserting inline
  assembly language. This is useful for interacting with OS level, for example
  writing platform-based shims.
  """
  @valid_opts [
    :sideeffect,
    :alignstack,
    :unwind,
    :dialect
  ]

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          fn_type: Type.Function.t(),
          asm: String.t(),
          constraints: String.t(),
          args: [Value.t()],
          sideeffect: boolean(),
          alignstack: boolean(),
          unwind: boolean(),
          dialect: atom()
        }
  defstruct [
    :id,
    :dest,
    :fn_type,
    :asm,
    :constraints,
    :args,
    :sideeffect,
    :alignstack,
    :unwind,
    :dialect
  ]

  @spec new(
          Types.destination(),
          Type.Function.t(),
          String.t(),
          String.t(),
          [Value.t()],
          keyword()
        ) :: __MODULE__.t()
  def new(dest, fn_type, asm, constraints, args, opts) do
    validate_opts!(opts)
    sideeffect = Keyword.get(opts, :sideeffect, false)
    alignstack = Keyword.get(opts, :alignstack, false)
    dialect = Keyword.get(opts, :dialect, :att)
    validate_dialect!(dialect)
    unwind = Keyword.get(opts, :unwind, false)

    Call.validate_args!(fn_type, args)

    %__MODULE__{
      id: make_ref(),
      dest: dest,
      fn_type: fn_type,
      asm: asm,
      constraints: constraints,
      args: args,
      sideeffect: sideeffect,
      alignstack: alignstack,
      dialect: dialect,
      unwind: unwind
    }
  end

  defp validate_opts!(opts) do
    opt_names = Keyword.keys(opts)
    unknown_opts = Enum.filter(opt_names, fn opt -> opt not in @valid_opts end)
    if !Enum.empty?(unknown_opts), do: raise("Invalid options: #{inspect(unknown_opts)}!")
  end

  defp validate_dialect!(:att), do: nil
  defp validate_dialect!(:intel), do: nil
  defp validate_dialect!(dialect), do: raise("invalid dialect #{dialect} option!")

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.CallASM do
  alias Wyvern.IR
  alias Wyvern.Type
  alias Wyvern.Instruction

  @doc """
  """
  def to_ir(
        %Instruction.CallASM{
          id: id,
          fn_type: fn_type,
          asm: asm,
          constraints: constraints,
          args: args
        } = ins,
        %IR.Context{} = ctx
      ) do
    # %ret = call i64 asm sideeffect "svc 0", "={x0},{x8},{x0},{x1},{x2},~{memory},~{cc}"(i64 #{@sys_write}, i64 %fd, i8* %buf, i64 %len)
    dest_str = resolve_dest(id, fn_type, ctx)
    {ret_type_str, ctx} = IR.to_ir(fn_type.ret_type, ctx)

    flags_str =
      [
        ins.sideeffect && "sideeffect",
        ins.alignstack && "alignstack",
        ins.dialect == :intel && "inteldialect",
        ins.unwind && "unwind"
      ]
      |> Enum.filter(& &1)
      |> Enum.map_join("", &(&1 <> " "))

    {args_ir, ctx} = Enum.map_reduce(args, ctx, &IR.to_ir/2)
    args_str = Enum.join(args_ir, ", ")

    if dest_str == nil do
      {~s[#{@for.mnemonic()} void asm #{flags_str}"#{asm}", "#{constraints}"(#{args_str})], ctx}
    else
      {~s[%#{dest_str} = #{@for.mnemonic()} #{ret_type_str} asm #{flags_str}"#{asm}", "#{constraints}"(#{args_str})],
       ctx}
    end
  end

  defp resolve_dest(id, fn_type, ctx) do
    if Type.void?(fn_type.ret_type) do
      nil
    else
      IR.Context.lookup_id(ctx, id)
    end
  end

  def resolve_names(
        %Instruction.CallASM{id: id, dest: dest, fn_type: fn_type},
        %IR.Context{} = ctx
      ) do
    if Type.void?(fn_type.ret_type) do
      ctx
    else
      IR.Context.map_id_to_name(ctx, id, dest)
    end
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.CallASM do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.CallASM{fn_type: %{ret_type: %Wyvern.Type.Void{}}}) do
    raise "ToHandle not supported in void call!"
  end

  def to_handle(%Wyvern.Instruction.CallASM{id: id, fn_type: %{ret_type: ret_type}}) do
    Handle.new(id, ret_type)
  end
end
