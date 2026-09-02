defmodule Wyvern.Type do
  @moduledoc """
  Represents an LLVM type e.g. :integer, :pointer
  """

  import Bitwise

  defmodule Integer do
    @type width :: pos_integer()
    @type t :: %__MODULE__{
            width: width()
          }
    defstruct [:width]

    @spec new(pos_integer()) :: __MODULE__.t()
    def new(width) do
      %__MODULE__{width: width}
    end
  end

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

  defmodule Float do
    @type variant :: :half | :bfloat | :float | :double | :x86_fp80 | :fp128 | :ppc_fp128
    @type t :: %__MODULE__{
            variant: variant()
          }
    defstruct [:variant]

    @spec new(variant()) :: __MODULE__.t()
    def new(variant) do
      %__MODULE__{variant: variant}
    end
  end

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

  defmodule Pointer do
    @type t :: %__MODULE__{}
    defstruct []

    @spec new() :: __MODULE__.t()
    def new() do
      %Pointer{}
    end
  end

  def ptr(), do: Pointer.new()
  def ptr?(%Pointer{}), do: true
  def ptr?(_), do: false

  defmodule Array do
    alias Wyvern.Type

    @type t :: %__MODULE__{
            type: Wyvern.Type.t(),
            len: non_neg_integer()
          }
    defstruct [:type, :len]

    @spec new(Type.t(), non_neg_integer()) :: __MODULE__.t()
    def new(type, len) do
      %__MODULE__{type: type, len: len}
    end
  end

  def array(type, len), do: Array.new(type, len)

  defmodule Struct do
    @type field_list :: [Wyvern.Type.t()]

    @type t :: %__MODULE__{
            fields: field_list(),
            packed: boolean()
          }
    defstruct fields: [], packed: false

    @spec new(field_list(), keyword()) :: __MODULE__.t()
    def new(fields, opts \\ []) when is_list(fields) and is_list(opts) do
      packed = Keyword.get(opts, :packed, false)
      %__MODULE__{fields: fields, packed: packed}
    end
  end

  def struct(fields, opts \\ []), do: Struct.new(fields, opts)

  defmodule NamedStruct do
    alias Wyvern.Identifier

    @type field_list :: [Wyvern.Type.t()]

    @type t :: %__MODULE__{
            name: String.t(),
            fields: field_list(),
            packed: boolean()
          }
    defstruct [:name, :fields, :packed]

    @spec new(String.t(), field_list(), keyword()) :: __MODULE__.t()
    def new(name, fields, opts \\ []) do
      packed = Keyword.get(opts, :packed, false)

      %__MODULE__{
        name: Identifier.legal_identifier(name),
        fields: fields,
        packed: packed
      }
    end
  end

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

  defmodule Function do
    @type param_list :: [Wyvern.Param.t()]

    @type t :: %__MODULE__{
            ret_type: Wyvern.Type.t(),
            params: param_list(),
            var_args: boolean()
          }
    defstruct ret_type: nil, params: [], var_args: false

    @spec new(Wyvern.Type.t(), param_list(), boolean()) :: __MODULE__.t()
    def new(ret_type, params, var_args) do
      %__MODULE__{ret_type: ret_type, params: params, var_args: var_args}
    end
  end

  def function(ret_type, params, var_args \\ false)
      when is_list(params) and is_boolean(var_args) do
    Function.new(ret_type, params, var_args)
  end

  defmodule Void do
    @type t :: %__MODULE__{}
    defstruct []

    @spec new() :: __MODULE__.t()
    def new() do
      %Void{}
    end
  end

  def void(), do: Void.new()

  def void?(%Void{}), do: true
  def void?(_), do: false

  defmodule Guards do
    defguard is_llvm_type(t)
             when is_struct(t, Integer) or is_struct(t, Float) or is_struct(t, Pointer) or
                    is_struct(t, Array) or is_struct(t, Function) or is_struct(t, Struct) or
                    is_struct(t, NamedStruct) or is_struct(t, Void)
  end

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
