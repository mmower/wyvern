defmodule Wyvern.Param do
  @moduledoc """
  A Param represents a parameter to a function that can be named or unnamed.

  In a Declaration you use unnamed to create an unnamed param.
  In a Function you use named to create a named param.
  """
  alias Wyvern.Type
  import Wyvern.Type.Guards
  alias Wyvern.Value.Handle

  # All legal param names
  # true means only present, no qualifier
  # :int means the qualifier is an integer
  # :type means the qualifier is a Type.t()
  @params [
    zeroext: true,
    signext: true,
    inreg: true,
    byval: :type,
    byref: :type,
    sret: :type,
    preallocated: :type,
    inalloca: :type,
    nest: true,
    returned: true,
    nonnull: true,
    dereferenceable: :int,
    dereferenceable_or_null: :int,
    align: :int,
    noalias: true,
    nocapture: true,
    readonly: true,
    readnone: true,
    writeonly: true,
    imarg: true,
    swiftself: true,
    swifterror: true,
    swiftasync: true,
    elementtype: :type,
    allocalign: true,
    allocptr: true,
    alignstack: :int
  ]
  @param_names Keyword.keys(@params)

  @type t :: %__MODULE__{
          id: reference(),
          name: nil | String.t(),
          type: Type.t(),
          attributes: keyword()
        }
  defstruct [:id, :name, :type, :attributes]

  @spec unnamed(Type.t(), keyword()) :: __MODULE__.t()
  def unnamed(type, attributes \\ []) when is_llvm_type(type) and is_list(attributes) do
    validate_attrs!(attributes, type)

    %__MODULE__{
      id: make_ref(),
      type: type,
      attributes: attributes
    }
  end

  @spec named(String.t(), Type.t(), keyword()) :: __MODULE__.t()
  def named(name, type, attributes \\ [])
      when is_binary(name) and is_llvm_type(type) and is_list(attributes) do
    validate_attrs!(attributes, type)

    %__MODULE__{
      id: make_ref(),
      name: name,
      type: type,
      attributes: attributes
    }
  end

  def ref(%__MODULE__{id: id, type: type}) do
    Handle.new(id, type)
  end

  defp validate_attrs!(attributes, type) do
    Enum.each(attributes, &validate_attr!(&1, type))
  end

  defp validate_attr!({name, _}, _type) when name not in @param_names,
    do: raise("unrecognised attribute #{name}!")

  defp validate_attr!({name, payload}, type) when name in [:sret, :byval] do
    if !is_llvm_type(payload),
      do: raise("illegal attribute payload #{inspect(payload)} for #{name}!")

    if !Type.ptr?(type), do: raise("illegal attribute #{name} for non-pointer param!")
  end

  defp validate_attr!({name, _payload}, type) when name in [:signext, :zeroext] do
    if !Type.integer?(type),
      do: raise("illegal non-integer value attribute #{name} for non-integer param!")
  end

  defp validate_attr!({name, payload}, _type) do
    case Keyword.fetch!(@params, name) do
      true ->
        if payload != true,
          do: raise("illegal attribute payload #{inspect(payload)} for #{name}!")

      :int ->
        if not is_integer(payload),
          do: raise("illegal attribute payload #{inspect(payload)} for #{name}!")

      :type ->
        if not is_llvm_type(payload),
          do: raise("illegal attribute payload #{inspect(payload)} for #{name}!")

      _ ->
        nil
    end
  end
end

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
