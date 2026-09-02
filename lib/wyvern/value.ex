defmodule Wyvern.Value do
  @moduledoc """
  Value represents a typed value, e.g. the integer 42.
  """
  alias Wyvern.Type
  alias Wyvern.Identifier

  defmodule Handle do
    @moduledoc """
    A Handle is used to refer to the value that is returned by
    an instruction and allow it to be passed as a value in the
    parameter of another instruction.

    In particular this unifies named and unnamed values where
    name resolution happens in a later step.
    """
    @type t :: %__MODULE__{
            id: reference(),
            type: Type.t()
          }
    defstruct [:id, :type]

    @spec new(reference(), Type.t()) :: __MODULE__.t()
    def new(id, type) when is_reference(id) do
      %__MODULE__{
        id: id,
        type: type
      }
    end
  end

  def handle(id, type), do: Handle.new(id, type)

  def handle(instruction), do: Wyvern.ToHandle.to_handle(instruction)

  defmodule Integer do
    @type t :: %__MODULE__{
            type: Type.Integer.t(),
            value: integer()
          }
    defstruct [:type, :value]

    @spec new(Type.Integer.t(), integer()) :: __MODULE__.t()
    def new(type, value) do
      %Integer{type: type, value: value}
    end
  end

  def i1(v), do: Integer.new(Type.i1(), v)
  def i8(v), do: Integer.new(Type.i8(), v)
  def i16(v), do: Integer.new(Type.i16(), v)
  def i32(v), do: Integer.new(Type.i32(), v)
  def i64(v), do: Integer.new(Type.i64(), v)

  defmodule Float do
    import Bitwise

    @type t :: %__MODULE__{
            type: Type.Float.t(),
            value: float()
          }
    defstruct [:type, :value]

    @spec new(Type.Float.t(), float()) :: __MODULE__.t()
    def new(%Type.Float{variant: :half} = type, value) do
      %Float{type: type, value: half_to_bits(value)}
    end

    def new(%Type.Float{variant: :bfloat} = type, value) do
      %Float{type: type, value: bfloat_to_bits(value)}
    end

    def new(%Type.Float{variant: :float} = type, value) do
      %Float{type: type, value: float_to_bits(value)}
    end

    def new(%Type.Float{variant: :double} = type, value) do
      %Float{type: type, value: double_to_bits(value)}
    end

    defp half_to_bits(v) do
      <<half_rounded::float-size(16)>> = <<v::float-size(16)>>
      <<bits::unsigned-integer-size(64)>> = <<half_rounded::float-size(64)>>
      bits
    end

    defp bfloat_to_bits(v) do
      <<float_bits::unsigned-integer-size(32)>> = <<v::float-size(32)>>
      bfloat_bits = float_bits >>> 16
      widened_bits = bfloat_bits <<< 16
      <<widened::float-size(32)>> = <<widened_bits::unsigned-integer-size(32)>>
      <<bits::unsigned-integer-size(64)>> = <<widened::float-size(64)>>
      bits
    end

    defp float_to_bits(v) do
      <<float_rounded::float-size(32)>> = <<v::float-size(32)>>
      <<bits::unsigned-integer-size(64)>> = <<float_rounded::float-size(64)>>
      bits
    end

    defp double_to_bits(v) when is_float(v) do
      <<bits::unsigned-integer-size(64)>> = <<v::float-size(64)>>
      bits
    end
  end

  def half(v), do: Float.new(Type.half(), v)
  def bfloat(v), do: Float.new(Type.bfloat(), v)
  def float(v), do: Float.new(Type.float(), v)
  def double(v), do: Float.new(Type.double(), v)

  defmodule Array do
    alias Wyvern.Type
    alias Wyvern.Value

    @type t :: %__MODULE__{
            type: Type.t(),
            elems: [Value.t()]
          }
    defstruct [:type, :elems]

    @spec new(Type.t(), [Value.t()]) :: __MODULE__.t()
    def new(type, elems) do
      validate_type(elems, type)
      validate_static(elems)

      %__MODULE__{
        type: Type.array(type, Enum.count(elems)),
        elems: elems
      }
    end

    defp validate_type([], _), do: true

    defp validate_type(elems, type) do
      unless Enum.all?(elems, &(&1.type == type)), do: raise("array element does not match type!")
    end

    defp validate_static(elems) do
      if Enum.any?(elems, &Value.dynamic_value?/1),
        do: raise("Unsupported dynamic value in array!")
    end
  end

  def array(type, elems), do: Array.new(type, elems)
  def array_value?(%Array{}), do: true
  def array_value?(_), do: false

  defmodule Struct do
    alias Wyvern.Value

    @type t :: %__MODULE__{
            type: Type.t(),
            fields: [Value.t()]
          }
    defstruct [:type, :fields]

    @spec new([Value.t()], keyword()) :: __MODULE__.t()
    def new(fields, opts) when is_list(opts) do
      if Enum.any?(fields, &Value.dynamic_value?/1),
        do: raise("Unsupported dynamic value in struct!")

      packed = Keyword.get(opts, :packed, false)

      field_types = Enum.map(fields, & &1.type)
      type = Wyvern.Type.struct(field_types, packed: packed)

      %__MODULE__{
        type: type,
        fields: fields
      }
    end
  end

  def struct(fields, opts \\ []), do: Struct.new(fields, opts)

  defmodule BlockAddress do
    @type t :: %__MODULE__{
            type: Type.t(),
            function: GlobalRef.t(),
            label: Label.t()
          }
    defstruct [:type, :function, :label]

    def new(function, label) do
      %__MODULE__{
        type: Type.ptr(),
        function: function,
        label: label
      }
    end
  end

  def blockaddress(function, label), do: BlockAddress.new(function, label)

  defmodule LocalRef do
    @type t :: %__MODULE__{
            type: Type.t(),
            name: String.t()
          }

    defstruct [:type, :name]

    @spec new(Type.t(), String.t()) :: __MODULE__.t()
    def new(type, name) when is_binary(name) do
      %__MODULE__{type: type, name: Identifier.legal_identifier(name)}
    end
  end

  @spec local_ref(Type.t(), String.t()) :: LocalRef.t()
  def local_ref(type, name) when is_binary(name), do: LocalRef.new(type, name)

  defmodule GlobalRef do
    @type t :: %__MODULE__{
            type: Type.t(),
            name: String.t()
          }
    defstruct [:type, :name]

    @spec new(String.t()) :: __MODULE__.t()
    def new(name) when is_binary(name) do
      %__MODULE__{type: Type.ptr(), name: Identifier.legal_identifier(name)}
    end
  end

  @spec global_ref(String.t()) :: GlobalRef.t()
  def global_ref(name) when is_binary(name), do: GlobalRef.new(name)

  defmodule Poison do
    import Wyvern.Type.Guards

    @type t :: %__MODULE__{
            type: Type.t()
          }
    defstruct [:type]

    @spec new(Type.t()) :: __MODULE__.t()
    def new(type) when is_llvm_type(type) do
      %__MODULE__{type: type}
    end
  end

  @spec poison(Type.t()) :: Poison.t()
  def poison(type), do: Poison.new(type)

  defmodule Undef do
    import Wyvern.Type.Guards

    @type t :: %__MODULE__{
            type: Type.t()
          }
    defstruct [:type]

    @spec new(Type.t()) :: __MODULE__.t()
    def new(type) when is_llvm_type(type) do
      %__MODULE__{type: type}
    end
  end

  @spec undef(Type.t()) :: Undef.t()
  def undef(type), do: Undef.new(type)

  defmodule Void do
    @type t :: %__MODULE__{}
    defstruct []

    def new() do
      %__MODULE__{}
    end
  end

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

  defmodule Guards do
    defguard is_llvm_value(v)
             when is_struct(v, Array) or is_struct(v, BlockAddress) or is_struct(v, Integer) or
                    is_struct(v, Float) or is_struct(v, LocalRef) or is_struct(v, GlobalRef) or
                    is_struct(v, Handle) or is_struct(v, Poison) or is_struct(v, Struct) or
                    is_struct(v, Undef) or is_struct(v, Void)
  end

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
