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
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.Float do
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
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
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.GlobalRef do
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
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
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IR, for: Wyvern.Value.Undef do
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
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
