defmodule Wyvern.Type do
  @moduledoc """
  Represents an LLVM type e.g. :integer, :pointer
  """

  import Bitwise

  alias Wyvern.Type.{
    Array,
    Float,
    Function,
    Integer,
    NamedStruct,
    Pointer,
    Struct,
    Void
  }

  @widths [1, 8, 16, 32, 64, 128]
  def min_width_type(n) when is_integer(n) do
    Enum.find(@widths, fn bits ->
      min = -(1 <<< (bits - 1))
      max = (1 <<< (bits - 1)) - 1
      n >= min && n <= max
    end)
    |> case do
      nil -> raise "Cannot store #{n} in i128!"
      w -> Integer.new(w)
    end
  end

  def i1(), do: Integer.new(1)
  def i8(), do: Integer.new(8)
  def i16(), do: Integer.new(16)
  def i32(), do: Integer.new(32)
  def i64(), do: Integer.new(64)
  def i128(), do: Integer.new(128)
  def char(), do: i8()

  def integer?(%Integer{}), do: true
  def integer?(_), do: false

  def half(), do: Float.new(:half)
  def bfloat(), do: Float.new(:bfloat)
  def float(), do: Float.new(:float)
  def double(), do: Float.new(:double)
  def x86_fp80(), do: Float.new(:x86_fp80)
  def fp128(), do: Float.new(:fp128)
  def ppc_fp128(), do: Float.new(:ppc_fp128)

  def float?(%Float{}), do: true
  def float?(_), do: false

  def float_width(%Float{variant: v}) when v in [:half, :bfloat], do: 16
  def float_width(%Float{variant: v}) when v in [:float], do: 32
  def float_width(%Float{variant: v}) when v in [:double], do: 64
  def float_width(%Float{}), do: raise("Unsupported - cannot get float width for variant!")
  def float_width(_), do: raise("Unsupported - cannot get float width for non float type!")

  def ptr(), do: Pointer.new()
  def ptr?(%Pointer{}), do: true
  def ptr?(_), do: false

  def array(type, len), do: Array.new(type, len)

  def struct(fields, opts \\ []), do: Struct.new(fields, opts)

  def named_struct(name, fields, opts \\ []), do: NamedStruct.new(name, fields, opts)

  def is_struct?(%Struct{}), do: true
  def is_struct?(%NamedStruct{}), do: true
  def is_struct?(_), do: false

  @doc """
  For struct and array types returns the inner type at the given index.
  """
  def field_type(%Wyvern.Type.Struct{fields: fields}, [_ | _] = index_list) do
    field_type(fields, index_list)
  end

  def field_type(%Wyvern.Type.NamedStruct{fields: fields}, [_ | _] = index_list) do
    field_type(fields, index_list)
  end

  def field_type(%Wyvern.Type.Array{type: type}, [_index | rest]) do
    field_type(type, rest)
  end

  def field_type(type, []), do: type

  def field_type(types, [index | rest]) when is_list(types) do
    if index < 0 || index >= length(types), do: raise("attempt to use invalid index!")
    field_type(Enum.at(types, index), rest)
  end

  def field_type(type, index_list) when index_list != [] do
    raise "cannot index into non-aggregate type #{inspect(type)}!"
  end

  def function(ret_type, params, var_args \\ false)
      when is_list(params) and is_boolean(var_args) do
    Function.new(ret_type, params, var_args)
  end

  def void(), do: Void.new()

  def void?(%Void{}), do: true
  def void?(_), do: false

  @typedoc """
  We declare `t` at the end to ensure we pick up our module definitions.
  """
  @type t ::
          Integer.t()
          | Float.t()
          | Pointer.t()
          | Array.t()
          | Function.t()
          | Struct.t()
          | NamedStruct.t()
          | Void.t()
end
