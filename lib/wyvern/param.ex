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
