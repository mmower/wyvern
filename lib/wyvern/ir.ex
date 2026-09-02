defmodule Wyvern.IR.Context do
  alias Wyvern.Label

  @moduledoc """
  A Context module is threaded through resolve_names()/to_ir() protocol to hold
  any state that is modified during the serialisation process.
  """
  @type t :: %__MODULE__{
          fn_auto_num: integer(),
          id_map: map()
        }
  defstruct fn_auto_num: 0, id_map: %{}

  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  defp resolve_name(%__MODULE__{fn_auto_num: n} = ctx, nil) do
    {"#{n}", %{ctx | fn_auto_num: n + 1}}
  end

  defp resolve_name(%__MODULE__{} = ctx, name) when is_binary(name) do
    {name, ctx}
  end

  def map_id_to_name(%__MODULE__{id_map: id_map} = ctx, id, name)
      when is_reference(id) and (is_nil(name) or is_binary(name)) do
    if Map.has_key?(id_map, id) do
      ctx
    else
      {resolved_name, ctx_1} = resolve_name(ctx, name)
      %{ctx_1 | id_map: Map.put_new(id_map, id, resolved_name)}
    end
  end

  def map_id_to_name(%__MODULE__{} = ctx, %Label{id: id, name: name}) do
    map_id_to_name(ctx, id, name)
  end

  def lookup_id(%__MODULE__{id_map: id_map}, id) do
    Map.fetch!(id_map, id)
  end
end

defprotocol Wyvern.IR do
  alias Wyvern.IR.Context

  @doc """
  Converts the term (expected to be an Wyvern struct) into a string representation of the IR
  ready to be passed to clang.
  """
  @spec to_ir(any(), Context.t()) :: {String.t(), Context.t()}
  def to_ir(term, ctx)

  @spec resolve_names(any(), Context.t()) :: Context.t()
  def resolve_names(term, ctx)
end

# Types

defimpl Wyvern.IR, for: Wyvern.Type.Integer do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Integer{width: w}, %IR.Context{} = ctx), do: {"i#{w}", ctx}
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Type.Float do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Float{variant: v}, %IR.Context{} = ctx), do: {"#{v}", ctx}
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Type.Pointer do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Pointer{}, %IR.Context{} = ctx), do: {"ptr", ctx}
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Type.Void do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Void{}, %IR.Context{} = ctx), do: {"void", ctx}
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Type.Array do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Array{type: type, len: len}, %IR.Context{} = ctx) do
    {type_s, ctx_2} = Wyvern.IR.to_ir(type, ctx)
    {"[#{len} x #{type_s}]", ctx_2}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Type.Struct do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.Struct{fields: fields, packed: packed}, %IR.Context{} = ctx) do
    fields
    |> Enum.map_reduce(ctx, &IR.to_ir/2)
    |> join_fields(packed)
  end

  defp join_fields({fields, ctx}, false) do
    {"{" <> Enum.join(fields, ", ") <> "}", ctx}
  end

  defp join_fields({fields, ctx}, true) do
    {"<{" <> Enum.join(fields, ", ") <> "}>", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Type.NamedStruct do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(%Type.NamedStruct{name: name}, %IR.Context{} = ctx) do
    {"%#{name}", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Type.Function do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(
        %Type.Function{ret_type: ret_type, params: params, var_args: false},
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {param_strs, ctx_2} = Enum.map_reduce(params, ctx_1, &IR.to_ir/2)
    params_joined = Enum.join(param_strs, ", ")
    {"#{ret_type_str} (#{params_joined})", ctx_2}
  end

  def to_ir(
        %Type.Function{ret_type: ret_type, params: [], var_args: true},
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {"#{ret_type_str} (...)", ctx_1}
  end

  def to_ir(
        %Type.Function{ret_type: ret_type, params: params, var_args: true},
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {param_strs, ctx_2} = Enum.map_reduce(params, ctx_1, &IR.to_ir/2)
    params_joined = Enum.join(param_strs, ", ")
    {"#{ret_type_str} (#{params_joined}, ...)", ctx_2}
  end

  def resolve_names(_, ctx), do: ctx
end

# Params

defimpl Wyvern.IR, for: Wyvern.Param do
  alias Wyvern.IR
  alias Wyvern.Param
  alias Wyvern.Identifier

  def to_ir(%Param{name: name, type: type, attributes: attributes}, %IR.Context{} = ctx) do
    name_str = if name, do: " %#{Identifier.legal_identifier(name)}", else: ""
    {type_str, ctx} = IR.to_ir(type, ctx)

    {attr_str, ctx} =
      if attributes == [] do
        {"", ctx}
      else
        {attr_str, ctx} = format_attributes(attributes, ctx)
        {" #{attr_str}", ctx}
      end

    {"#{type_str}#{attr_str}#{name_str}", ctx}
  end

  def resolve_names(%Param{id: id, name: name}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, name)
  end

  defp format_attributes(attributes, ctx) do
    {attributes_ir, ctx} = Enum.map_reduce(attributes, ctx, &format_attribute/2)
    attributes_str = Enum.join(attributes_ir, " ")
    {attributes_str, ctx}
  end

  defp format_attribute({key, true}, ctx), do: {"#{key}", ctx}

  defp format_attribute({key, value}, ctx) do
    {value_ir, ctx} = IR.to_ir(value, ctx)
    {"#{key}(#{value_ir})", ctx}
  end
end

# Values

defimpl Wyvern.IR, for: Wyvern.Value.Integer do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.Integer{type: type, value: value}, %IR.Context{} = ctx) do
    {type_str, ctx_1} = IR.to_ir(type, ctx)
    {"#{type_str} #{value}", ctx_1}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.Float do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.Float{type: type, value: value}, %IR.Context{} = ctx) do
    {type_str, ctx_1} = IR.to_ir(type, ctx)

    value_str =
      value
      |> Integer.to_string(16)
      |> String.pad_leading(16, "0")
      |> String.downcase()

    {"#{type_str} 0x#{value_str}", ctx_1}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.BlockAddress do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.Value

  def to_ir(
        %Value.BlockAddress{function: %Value.GlobalRef{name: fn_name}, label: label},
        %IR.Context{} = ctx
      ) do
    label_str = IR.Context.lookup_id(ctx, label.id) |> Identifier.legal_identifier()
    {"ptr blockaddress(@#{fn_name}, %#{label_str})", ctx}
  end

  def resolve_names(%Value.BlockAddress{label: label}, %IR.Context{} = ctx) do
    IR.resolve_names(label, ctx)
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.LocalRef do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.LocalRef{type: type, name: name}, ctx) do
    {type_str, out_ctx} = IR.to_ir(type, ctx)
    {"#{type_str} %#{name}", out_ctx}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.GlobalRef do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.GlobalRef{type: type, name: name}, %IR.Context{} = ctx) do
    {type_str, out_ctx} = IR.to_ir(type, ctx)
    {"#{type_str} @#{name}", out_ctx}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.Struct do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.Struct{type: type, fields: fields}, %IR.Context{} = ctx) do
    {type_str, ctx} = IR.to_ir(type, ctx)
    {fields_ir, ctx} = Enum.map_reduce(fields, ctx, &IR.to_ir/2)
    fields_str = Enum.join(fields_ir, ", ")

    value_str =
      if type.packed do
        "<{" <> fields_str <> "}>"
      else
        "{" <> fields_str <> "}"
      end

    {"#{type_str} #{value_str}", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.Array do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.Array{type: type, elems: elems}, %IR.Context{} = ctx) do
    {type_str, ctx} = IR.to_ir(type, ctx)
    {elems_ir, ctx} = Enum.map_reduce(elems, ctx, &IR.to_ir/2)
    elems_str = Enum.join(elems_ir, ", ")
    {"#{type_str} [#{elems_str}]", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.Poison do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.Poison{type: type}, %IR.Context{} = ctx) do
    {type_str, ctx} = IR.to_ir(type, ctx)
    {"#{type_str} poison", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.Undef do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_ir(%Value.Undef{type: type}, %IR.Context{} = ctx) do
    {type_str, ctx} = IR.to_ir(type, ctx)
    {"#{type_str} undef", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.Void do
  alias Wyvern.Value

  def to_ir(%Value.Void{}, ctx) do
    {"void", ctx}
  end

  def resolve_names(_, ctx), do: ctx
end

# Instructions

defimpl Wyvern.IR, for: Wyvern.Instruction.Add do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Add{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = add #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Add{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
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
      {"%#{dest_str} = alloca #{type_str}, #{count_type_str} #{count}", ctx_2}
    else
      {"%#{dest_str} = alloca #{type_str}", ctx_1}
    end
  end

  def to_ir(
        %Instruction.Alloca{id: id, type: type, count: %{type: %Type.Integer{}} = count},
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(type, ctx)
    {count_str, ctx_2} = IR.to_ir(count, ctx_1)
    {"%#{dest_str} = alloca #{type_str}, #{count_str}", ctx_2}
  end

  def resolve_names(%Instruction.Alloca{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.And do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.And{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = and #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.And{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Ashr do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Ashr{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = ashr #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Ashr{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.BR do
  alias Wyvern.IR
  alias Wyvern.Label
  alias Wyvern.Identifier
  alias Wyvern.Instruction

  def to_ir(%Instruction.BR{cond: nil, if_true: if_true}, %IR.Context{} = ctx) do
    label = IR.Context.lookup_id(ctx, if_true.id) |> Identifier.legal_identifier()
    {"br label %#{label}", ctx}
  end

  def to_ir(
        %Instruction.BR{
          cond: cond,
          if_true: if_true,
          if_false: nil
        },
        ctx
      ) do
    {cond_str, ctx_1} = IR.to_ir(cond, ctx)
    true_label = IR.Context.lookup_id(ctx, if_true.id) |> Identifier.legal_identifier()
    {"br #{cond_str}, label %#{true_label}", ctx_1}
  end

  def to_ir(
        %Instruction.BR{
          cond: cond,
          if_true: if_true,
          if_false: if_false
        },
        %IR.Context{} = ctx
      ) do
    {cond_str, ctx_1} = IR.to_ir(cond, ctx)

    true_label = IR.Context.lookup_id(ctx, if_true.id) |> Identifier.legal_identifier()
    false_label = IR.Context.lookup_id(ctx, if_false.id) |> Identifier.legal_identifier()

    {"br #{cond_str}, label %#{true_label}, label %#{false_label}", ctx_1}
  end

  def resolve_names(%Instruction.BR{if_true: if_true, if_false: if_false}, %IR.Context{} = ctx) do
    ctx
    |> then(&IR.resolve_names(if_true, &1))
    |> then(fn ctx ->
      if is_nil(if_false), do: ctx, else: IR.resolve_names(if_false, ctx)
    end)
  end
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
      {"call #{ret_type_str} #{args_shape}#{fn_str}(#{args_str})", ctx_4}
    else
      {"%#{dest_str} = call #{ret_type_str} #{args_shape}#{fn_str}(#{args_str})", ctx_4}
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
    {"%#{dest_str} = extractvalue #{agg_str}, #{index_str}", ctx}
  end

  def resolve_names(%Instruction.ExtractValue{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fadd do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Fadd{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = fadd #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Fadd{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fsub do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Fsub{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = fsub #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Fsub{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fmul do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Fmul{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = fmul #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Fmul{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fdiv do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Fdiv{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = fdiv #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Fdiv{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fneg do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Wyvern.Instruction.Fneg{id: id, src: src}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {"%#{dest_str} = fneg #{src_str}", ctx_1}
  end

  def resolve_names(%Wyvern.Instruction.Fneg{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Frem do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Frem{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = frem #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Frem{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fcmp do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.Fcmp{id: id, operation: operation, op1: op1, op2: op2},
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    op_str = Atom.to_string(operation)
    {op1_str, ctx_1} = IR.to_ir(op1, ctx)
    {op2_str, ctx_2} = IROperand.to_operand(op2, ctx_1)
    {"%#{dest_str} = fcmp #{op_str} #{op1_str}, #{op2_str}", ctx_2}
  end

  def resolve_names(%Instruction.Fcmp{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fptrunc do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Fptrunc{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = fptrunc #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.Fptrunc{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fpext do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Fpext{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = fpext #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.Fpext{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fptosi do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Fptosi{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = fptosi #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.Fptosi{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fptoui do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Fptoui{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = fptoui #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.Fptoui{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Freeze do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Freeze{id: id, src: src}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx} = IR.to_ir(src, ctx)
    {"%#{dest_str} = freeze #{src_str}", ctx}
  end

  def resolve_names(%Instruction.Freeze{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.GetElementPtr do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.GetElementPtr{
          id: id,
          type: type,
          source: source,
          indices: indices,
          inbounds: inbounds
        },
        ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    inbounds_str = if inbounds, do: "inbounds ", else: ""
    {type_str, ctx_1} = IR.to_ir(type, ctx)
    {source_name, ctx_2} = IR.to_ir(source, ctx_1)
    {index_names, ctx_3} = Enum.map_reduce(indices, ctx_2, &IR.to_ir/2)
    index_str = Enum.join(index_names, ", ")

    {"%#{dest_str} = getelementptr #{inbounds_str}#{type_str}, #{source_name}, #{index_str}",
     ctx_3}
  end

  def resolve_names(%Instruction.GetElementPtr{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Icmp do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  @doc """
  Implemented: <result> = icmp <cond> <ty> <op1>, <op2>   ; yields i1 or <N x i1>:result
  Not implemented: <result> = icmp samesign <cond> <ty> <op1>, <op2>   ; yields i1 or <N x i1>:result
  """

  def to_ir(
        %Instruction.Icmp{id: id, operation: operation, op1: op1, op2: op2},
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    op_str = Atom.to_string(operation)
    {op1_str, ctx_1} = IR.to_ir(op1, ctx)
    {op2_str, ctx_2} = IROperand.to_operand(op2, ctx_1)
    {"%#{dest_str} = icmp #{op_str} #{op1_str}, #{op2_str}", ctx_2}
  end

  def resolve_names(%Instruction.Icmp{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.IndirectBr do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.IndirectBr{address: address, destinations: destinations},
        %IR.Context{} = ctx
      ) do
    {addr_str, ctx} = IR.to_ir(address, ctx)

    labels =
      Enum.map_join(
        destinations,
        ", ",
        &(IR.Context.lookup_id(ctx, &1.id)
          |> Identifier.legal_identifier()
          |> String.replace_prefix("", "label %"))
      )

    {"indirectbr #{addr_str}, [#{labels}]", ctx}
  end

  def resolve_names(
        %Instruction.IndirectBr{destinations: destinations},
        %IR.Context{} = ctx
      ) do
    Enum.reduce(destinations, ctx, fn destination, ctx ->
      IR.Context.map_id_to_name(ctx, destination.id, destination.name)
    end)
  end
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

    {"%#{dest_str} = insertvalue #{agg_str}, #{value_str}, #{index_str}", ctx}
  end

  def resolve_names(%Instruction.InsertValue{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.IntToPtr do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.IntToPtr{id: id, src: src}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {"%#{dest_str} = inttoptr #{src_str} to ptr", ctx_1}
  end

  def resolve_names(%Instruction.IntToPtr{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Load do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Load{id: id, type: type, src: src}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(type, ctx)
    {src_str, ctx_2} = IR.to_ir(src, ctx_1)
    {"%#{dest_str} = load #{type_str}, #{src_str}", ctx_2}
  end

  def resolve_names(%Instruction.Load{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Lshr do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Lshr{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = lshr #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Lshr{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Mul do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Mul{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = mul #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Mul{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Or do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Or{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = or #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Or{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Phi do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Phi{id: id, type: type, incoming: incoming}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(type, ctx)

    {pairs, ctx_2} =
      Enum.map_reduce(incoming, ctx_1, fn {value, label}, acc_ctx ->
        {value_str, acc_ctx_1} = IROperand.to_operand(value, acc_ctx)
        label_str = IR.Context.lookup_id(acc_ctx_1, label.id) |> Identifier.legal_identifier()
        {"[#{value_str}, %#{label_str}]", acc_ctx_1}
      end)

    {"%#{dest_str} = phi #{type_str} #{Enum.join(pairs, ", ")}", ctx_2}
  end

  def resolve_names(%Instruction.Phi{id: id, dest: dest, incoming: incoming}, ctx) do
    ctx_1 = IR.Context.map_id_to_name(ctx, id, dest)

    Enum.reduce(incoming, ctx_1, fn {_value, label}, acc_ctx ->
      IR.resolve_names(label, acc_ctx)
    end)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.PtrToInt do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.PtrToInt{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = ptrtoint #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.PtrToInt{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Ret do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Ret{value: value}, %IR.Context{} = ctx) do
    {value_str, ctx_1} = IR.to_ir(value, ctx)
    {"ret #{value_str}", ctx_1}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Sdiv do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Sdiv{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = sdiv #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Sdiv{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Select do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.Select{id: id, cond: cond, if_true: if_true, if_false: if_false},
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {cond_str, ctx} = IR.to_ir(cond, ctx)
    {if_true_str, ctx} = IR.to_ir(if_true, ctx)
    {if_false_str, ctx} = IR.to_ir(if_false, ctx)
    {"%#{dest_str} = select #{cond_str}, #{if_true_str}, #{if_false_str}", ctx}
  end

  def resolve_names(%Instruction.Select{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Sext do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Sext{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = sext #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.Sext{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Shl do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Shl{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = shl #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Shl{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Sitofp do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Sitofp{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = sitofp #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.Sitofp{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Srem do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Srem{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = srem #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Srem{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Store do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Store{value: value, dest: dest}, %IR.Context{} = ctx) do
    {value_str, ctx_1} = IR.to_ir(value, ctx)
    {dest_str, ctx_2} = IR.to_ir(dest, ctx_1)
    {"store #{value_str}, #{dest_str}", ctx_2}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Sub do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Sub{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = sub #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Sub{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Switch do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.Switch{value: value, default_label: default_label, cases: cases},
        %IR.Context{} = ctx
      )
      when is_list(cases) do
    {value_str, ctx_1} = IR.to_ir(value, ctx)

    default_label_str =
      IR.Context.lookup_id(ctx, default_label.id) |> Identifier.legal_identifier()

    {case_strs, ctx_2} =
      Enum.map_reduce(cases, ctx_1, fn {value, label}, acc_ctx ->
        {value_str, acc_ctx_1} = IR.to_ir(value, acc_ctx)
        label_str = IR.Context.lookup_id(acc_ctx_1, label.id) |> Identifier.legal_identifier()
        {"#{value_str}, label %#{label_str}", acc_ctx_1}
      end)

    case_str = Enum.join(case_strs, " ")
    {"switch #{value_str}, label %#{default_label_str} [#{case_str}]", ctx_2}
  end

  def resolve_names(
        %Instruction.Switch{default_label: default_label, cases: cases},
        %IR.Context{} = ctx
      ) do
    case_labels = Enum.map(cases, fn {_value, label} -> label end)

    Enum.reduce([default_label | case_labels], ctx, fn label, ctx ->
      IR.resolve_names(label, ctx)
    end)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Trunc do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Trunc{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = trunc #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.Trunc{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Udiv do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Udiv{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = udiv #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Udiv{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Uitofp do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Uitofp{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = uitofp #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.Uitofp{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Urem do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Urem{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = urem #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Urem{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Unreachable do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Unreachable{}, %IR.Context{} = ctx) do
    {"unreachable", ctx}
  end

  def resolve_names(%Instruction.Unreachable{}, %IR.Context{} = ctx) do
    ctx
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Xor do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Xor{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = xor #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  def resolve_names(%Instruction.Xor{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Zext do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Zext{id: id, src: src, to_type: to_type}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = zext #{src_str} to #{type_str}", ctx_2}
  end

  def resolve_names(%Instruction.Zext{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.IR, for: Wyvern.Label do
  alias Wyvern.IR
  alias Wyvern.Label

  def to_ir(%Label{}, _ctx) do
    raise "Not implemented!"
  end

  def resolve_names(%Label{id: id, name: name}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, name)
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.Handle do
  alias Wyvern.IR
  alias Wyvern.Value.Handle

  def to_ir(%Handle{id: id, type: type}, %IR.Context{} = ctx) do
    name = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(type, ctx)
    {"#{type_str} %#{name}", ctx_1}
  end

  @doc """
  Names have already been resolved.
  """
  def resolve_names(%Handle{}, %IR.Context{} = ctx) do
    ctx
  end
end

defimpl Wyvern.IR, for: Wyvern.BasicBlock do
  alias Wyvern.IR
  alias Wyvern.Label
  alias Wyvern.BasicBlock

  def to_ir(%BasicBlock{label: %Label{id: id}, instructions: instructions}, %IR.Context{} = ctx) do
    name_str = IR.Context.lookup_id(ctx, id)
    {ins_ir, ctx_2} = Enum.map_reduce(instructions, ctx, &IR.to_ir/2)
    ins_str = ins_ir |> Enum.map(fn ins -> "  #{ins}" end) |> Enum.join("\n")
    {"#{name_str}:\n#{ins_str}", ctx_2}
  end

  def resolve_names(
        %BasicBlock{label: %Label{} = label, instructions: instructions},
        %IR.Context{} = ctx
      ) do
    ctx_1 = IR.Context.map_id_to_name(ctx, label)
    Enum.reduce(instructions, ctx_1, &IR.resolve_names/2)
  end
end

defimpl Wyvern.IR, for: Wyvern.Function do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.Function

  def to_ir(
        %Function{
          name: name,
          ret_type: ret_type,
          params: params,
          blocks: blocks,
          linkage: linkage,
          visibility: visibility,
          addr: addr,
          cconv: cconv
        },
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)

    {params_mapped, ctx_2} = Enum.map_reduce(params, ctx_1, &IR.to_ir/2)
    params_str = Enum.join(params_mapped, ", ")

    {blocks_mapped, ctx_3} = Enum.map_reduce(blocks, ctx_2, &IR.to_ir/2)
    blocks_str = Enum.join(blocks_mapped, "\n")

    {"define #{linkage_keyword(linkage)}#{visibility_keyword(visibility)}#{cconv_keyword(cconv)}#{ret_type_str} @#{Identifier.legal_identifier(name)}(#{params_str})#{addr_keyword(addr)} {\n#{blocks_str}\n}",
     ctx_3}
  end

  defp linkage_keyword(nil), do: ""
  defp linkage_keyword(linkage), do: "#{linkage} "

  defp visibility_keyword(nil), do: ""
  defp visibility_keyword(visibility), do: "#{visibility} "

  defp addr_keyword(nil), do: ""
  defp addr_keyword(addr), do: " #{addr}"

  defp cconv_keyword(nil), do: ""
  defp cconv_keyword(cconv), do: "#{cconv} "

  def resolve_names(%Function{params: params, blocks: blocks}, %IR.Context{} = ctx) do
    Enum.reduce(params ++ blocks, ctx, &IR.resolve_names/2)
  end
end

defimpl Wyvern.IR, for: Wyvern.GlobalVariable do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.GlobalVariable

  def to_ir(
        %GlobalVariable{
          name: name,
          type: type,
          initializer: nil,
          mutable: mutable,
          linkage: linkage,
          visibility: visibility,
          addr: addr
        },
        %IR.Context{} = ctx
      ) do
    name = Identifier.legal_identifier(name)
    keyword = if mutable, do: "global", else: "constant"
    {type_str, ctx} = IR.to_ir(type, ctx)

    {"@#{name} = #{linkage_keyword(linkage, "external")}#{visibility_keyword(visibility)}#{addr_keyword(addr)}#{keyword} #{type_str}",
     ctx}
  end

  def to_ir(
        %GlobalVariable{
          name: name,
          initializer: initializer,
          mutable: mutable,
          linkage: linkage,
          visibility: visibility,
          addr: addr
        },
        %IR.Context{} = ctx
      ) do
    ins_name = if mutable, do: "global", else: "constant"
    name = Identifier.legal_identifier(name)
    {value_str, ctx} = IR.to_ir(initializer, ctx)

    {"@#{name} = #{linkage_keyword(linkage, nil)}#{visibility_keyword(visibility)}#{addr_keyword(addr)}#{ins_name} #{value_str}",
     ctx}
  end

  defp linkage_keyword(nil, nil), do: ""
  defp linkage_keyword(nil, default), do: "#{default} "
  defp linkage_keyword(linkage, _default), do: "#{linkage} "

  defp visibility_keyword(nil), do: ""
  defp visibility_keyword(visibility), do: "#{visibility} "

  defp addr_keyword(nil), do: ""
  defp addr_keyword(address), do: "#{address} "

  def resolve_names(%GlobalVariable{initializer: nil}, %IR.Context{} = ctx), do: ctx

  def resolve_names(%GlobalVariable{initializer: initializer}, %IR.Context{} = ctx),
    do: IR.resolve_names(initializer, ctx)
end

defimpl Wyvern.IR, for: Wyvern.Declaration do
  alias Wyvern.IR
  alias Wyvern.Type
  alias Wyvern.Identifier
  alias Wyvern.Declaration

  def to_ir(
        %Declaration{
          name: name,
          type: %Type.Function{ret_type: ret_type, params: params, var_args: false}
        },
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {param_strs, ctx_2} = Enum.map_reduce(params, ctx_1, &IR.to_ir/2)
    params_joined = Enum.join(param_strs, ", ")
    {"declare #{ret_type_str} @#{Identifier.legal_identifier(name)}(#{params_joined})", ctx_2}
  end

  def to_ir(
        %Declaration{
          name: name,
          type: %Type.Function{ret_type: ret_type, params: [], var_args: true}
        },
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {"declare #{ret_type_str} @#{Identifier.legal_identifier(name)}(...)", ctx_1}
  end

  def to_ir(
        %Declaration{
          name: name,
          type: %Type.Function{ret_type: ret_type, params: params, var_args: true}
        },
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {param_strs, ctx_2} = Enum.map_reduce(params, ctx_1, &IR.to_ir/2)
    params_joined = Enum.join(param_strs, ", ")

    {"declare #{ret_type_str} @#{Identifier.legal_identifier(name)}(#{params_joined}, ...)",
     ctx_2}
  end

  def resolve_names(_, %IR.Context{} = ctx), do: ctx
end

defprotocol Wyvern.IROperand do
  alias Wyvern.IR.Context

  @spec to_operand(any(), Context.t()) :: {String.t(), Context.t()}
  def to_operand(term, ctx)
end

defimpl Wyvern.IROperand, for: Wyvern.Value.Integer do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.Integer{value: value}, %IR.Context{} = ctx) do
    {"#{value}", ctx}
  end
end

defimpl Wyvern.IROperand, for: Wyvern.Value.Float do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.Float{value: value}, %IR.Context{} = ctx) do
    value_str =
      value
      |> Integer.to_string(16)
      |> String.pad_leading(16, "0")
      |> String.downcase()

    {"0x#{value_str}", ctx}
  end
end

defimpl Wyvern.IROperand, for: Wyvern.Value.LocalRef do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.LocalRef{name: name}, %IR.Context{} = ctx) do
    {"%#{name}", ctx}
  end
end

defimpl Wyvern.IROperand, for: Wyvern.Value.GlobalRef do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.GlobalRef{name: name}, %IR.Context{} = ctx) do
    {"@#{name}", ctx}
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

defimpl Wyvern.IROperand, for: Wyvern.Value.Poison do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.Poison{}, %IR.Context{} = ctx) do
    {"poison", ctx}
  end
end

defimpl Wyvern.IROperand, for: Wyvern.Value.Undef do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.Undef{}, %IR.Context{} = ctx) do
    {"undef", ctx}
  end
end
