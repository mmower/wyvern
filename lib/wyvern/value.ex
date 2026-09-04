defmodule Wyvern.Value do
  @moduledoc """
  Value represents a typed value, e.g. the integer 42.
  """
  alias Wyvern.Type

  alias Wyvern.Value.{
    Array,
    BlockAddress,
    Float,
    GlobalRef,
    Handle,
    Integer,
    LocalRef,
    Poison,
    Struct,
    Undef,
    Void
  }

  def handle(id, type), do: Handle.new(id, type)

  def handle(instruction), do: Wyvern.ToHandle.to_handle(instruction)

  def i1(v), do: Integer.new(Type.i1(), v)
  def i8(v), do: Integer.new(Type.i8(), v)
  def i16(v), do: Integer.new(Type.i16(), v)
  def i32(v), do: Integer.new(Type.i32(), v)
  def i64(v), do: Integer.new(Type.i64(), v)

  def half(v), do: Float.new(Type.half(), v)
  def bfloat(v), do: Float.new(Type.bfloat(), v)
  def float(v), do: Float.new(Type.float(), v)
  def double(v), do: Float.new(Type.double(), v)

  def array(type, elems), do: Array.new(type, elems)
  def array_value?(%Array{}), do: true
  def array_value?(_), do: false

  def struct(fields, opts \\ []), do: Struct.new(fields, opts)

  def blockaddress(function, label), do: BlockAddress.new(function, label)

  @spec local_ref(Type.t(), String.t()) :: LocalRef.t()
  def local_ref(type, name) when is_binary(name), do: LocalRef.new(type, name)

  @spec global_ref(String.t()) :: GlobalRef.t()
  def global_ref(name) when is_binary(name), do: GlobalRef.new(name)

  @spec poison(Type.t()) :: Poison.t()
  def poison(type), do: Poison.new(type)

  @spec undef(Type.t()) :: Undef.t()
  def undef(type), do: Undef.new(type)

  @spec void() :: Void.t()
  def void(), do: Void.new()

  def dynamic_value?(%LocalRef{}), do: true
  def dynamic_value?(%Handle{}), do: true
  def dynamic_value?(%Struct{fields: fields}), do: Enum.any?(fields, &dynamic_value?/1)
  def dynamic_value?(_), do: false

  def zero?(%Integer{value: 0}), do: true
  def zero?(%Float{value: 0}), do: true
  def zero?(%Array{elems: elems}), do: Enum.all?(elems, &zero?/1)
  def zero?(%Struct{fields: fields}), do: Enum.all?(fields, &zero?/1)
  def zero?(_), do: false

  @type t ::
          Array.t()
          | BlockAddress.t()
          | Integer.t()
          | Float.t()
          | LocalRef.t()
          | GlobalRef.t()
          | Handle.t()
          | Poison.t()
          | Struct.t()
          | Undef.t()
          | Void.t()
end
