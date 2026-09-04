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
