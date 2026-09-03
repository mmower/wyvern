defmodule Wyvern.Instruction do
  @moduledoc """
  The modules in this namespace represent the LLVM instruction set.
  """

  alias Wyvern.Type
  alias Wyvern.Label
  alias Wyvern.Value

  defmodule Types do
    @type destination :: String.t() | nil
  end

  defmodule Add do
    @type operand :: Value.t()

    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, %{type: op1_type} = op1, %{type: op2_type} = op2) do
      if op1_type != op2_type, do: raise("Unsupported attempt to mix types!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def add(dest, op1, op2), do: Add.new(dest, op1, op2)

  defmodule Alloca do
    @type count :: Value.t() | pos_integer()
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            type: Type.t(),
            count: count()
          }
    defstruct [:id, :dest, :type, :count]

    @spec new(Types.destination(), Type.t(), count()) :: __MODULE__.t()

    def new(dest, type, count) when is_integer(count) do
      %__MODULE__{
        id: make_ref(),
        dest: dest,
        type: type,
        count: count
      }
    end

    def new(dest, type, %{type: %Type.Integer{}} = count) do
      %__MODULE__{
        id: make_ref(),
        dest: dest,
        type: type,
        count: count
      }
    end
  end

  def alloca(dest, type, count \\ 1), do: Alloca.new(dest, type, count)

  defmodule And do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("and - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "and - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def bit_and(dest, op1, op2), do: And.new(dest, op1, op2)

  defmodule Ashr do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("ashr - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "ashr - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def ashr(dest, op1, op2), do: Ashr.new(dest, op1, op2)

  defmodule BR do
    @type t :: %__MODULE__{
            id: reference(),
            cond: Value.t(),
            if_true: Label.t(),
            if_false: Label.t() | nil
          }
    defstruct [:id, :cond, :if_true, :if_false]

    @spec unconditional(Label.t()) :: __MODULE__.t()
    def unconditional(%Label{} = if_true) do
      %__MODULE__{id: make_ref(), cond: nil, if_true: if_true, if_false: nil}
    end

    @spec conditional(Value.t(), Label.t()) :: __MODULE__.t()
    def conditional(cond, %Label{} = if_true) do
      if cond.type != Type.i1(), do: raise("cond must be type i1!")
      %__MODULE__{id: make_ref(), cond: cond, if_true: if_true, if_false: nil}
    end

    @spec conditional(Value.t(), Label.t(), Label.t()) :: __MODULE__.t()
    def conditional(cond, %Label{} = if_true, %Label{} = if_false) do
      if cond.type != Type.i1(), do: raise("cond must be i1!")
      %__MODULE__{id: make_ref(), cond: cond, if_true: if_true, if_false: if_false}
    end
  end

  def br(label), do: BR.unconditional(label)
  def br(cond, if_true), do: BR.conditional(cond, if_true)
  def br(cond, if_true, if_false), do: BR.conditional(cond, if_true, if_false)

  defmodule Call do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            fn_type: Type.Function.t(),
            fn_ref: Value.t(),
            args: [Value.t()]
          }
    defstruct [:id, :dest, :fn_type, :fn_ref, :args]

    @spec new(Types.destination(), Type.Function.t(), Value.t(), [Value.t()]) :: __MODULE__.t()
    def new(dest, fn_type, fn_ref, args) do
      if !is_nil(dest) && Type.void?(fn_type.ret_type),
        do: raise("Unsupported: cannot return from a void function!")

      unless Type.ptr?(fn_ref.type), do: raise("Unsupported: attempt to call non-pointer target!")

      validate_args!(fn_type, args)

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        fn_type: fn_type,
        fn_ref: fn_ref,
        args: args
      }
    end

    def validate_args!(fn_type, args) do
      if !fn_type.var_args && length(fn_type.params) != length(args),
        do: raise("Attempt to call function with wrong number of arguments!")

      if fn_type.var_args && length(args) < length(fn_type.params),
        do: raise("Attempt to call function with insufficient arguments!")

      arg_types = Enum.map(args, & &1.type)
      mappings = Enum.zip(arg_types, fn_type.params)

      if Enum.filter(mappings, fn {arg_type, param} -> arg_type != param end) != [] do
        raise "Attempt to call function with different argument types!"
      end
    end
  end

  def call(dest, fn_type, fn_ref, args), do: Call.new(dest, fn_type, fn_ref, args)

  defmodule CallASM do
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
  end

  def call_asm(dest, fn_type, asm, constraints, args, opts),
    do: CallASM.new(dest, fn_type, asm, constraints, args, opts)

  defmodule Fadd do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.float?(op1.type), do: raise("fadd - only supports float types!")
      unless op1.type == op2.type, do: raise("fadd - operands have different types!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  defmodule ExtractValue do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            aggregate: Value.t(),
            index_list: [non_neg_integer()],
            value_type: Type.t()
          }
    defstruct [:id, :dest, :aggregate, :index_list, :value_type]

    def new(dest, aggregate, index_list) do
      validate_index_list(index_list)
      value_type = Type.field_type(aggregate.type, index_list)

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        aggregate: aggregate,
        index_list: index_list,
        value_type: value_type
      }
    end

    defp validate_index_list(index_list) do
      if length(index_list) < 1,
        do: raise("extractvalue - must specify at least one index value!")

      unless Enum.all?(index_list, fn index -> is_integer(index) && index >= 0 end),
        do: raise("extractvalue - indexes must be non-negative integers!")
    end
  end

  def extract_value(dest, aggregate, index_list),
    do: ExtractValue.new(dest, aggregate, index_list)

  def fadd(dest, op1, op2), do: Fadd.new(dest, op1, op2)

  defmodule Fsub do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.float?(op1.type), do: raise("fsub - only supports float types!")
      unless op1.type == op2.type, do: raise("fsub - operands have different types!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def fsub(dest, op1, op2), do: Fsub.new(dest, op1, op2)

  defmodule Fmul do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.float?(op1.type), do: raise("fmul - only supports float types!")
      unless op1.type == op2.type, do: raise("fmul - operands have different types!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def fmul(dest, op1, op2), do: Fmul.new(dest, op1, op2)

  defmodule Fneg do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t()
          }
    defstruct [:id, :dest, :src]

    @spec new(Types.destination(), Value.t()) :: __MODULE__.t()
    def new(dest, src) do
      unless Type.float?(src.type), do: raise("fneg - requires floating point source!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src
      }
    end
  end

  def fneg(dest, src), do: Fneg.new(dest, src)

  defmodule Fdiv do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.float?(op1.type), do: raise("fdiv - only supports float types!")
      unless op1.type == op2.type, do: raise("fdiv - operands have different types!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def fdiv(dest, op1, op2), do: Fdiv.new(dest, op1, op2)

  defmodule Frem do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.float?(op1.type), do: raise("frem - only supports float types!")
      unless op1.type == op2.type, do: raise("frem - operands have different types!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def frem(dest, op1, op2), do: Frem.new(dest, op1, op2)

  defmodule Fcmp do
    @type operation :: atom()
    @type operand :: Value.t()
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            operation: operation(),
            op1: operand(),
            op2: operand()
          }
    defstruct [:id, :dest, :operation, :op1, :op2]

    @legal_ops [
      false,
      :oeq,
      :ogt,
      :oge,
      :olt,
      :ole,
      :one,
      :ord,
      :ueq,
      :ugt,
      :uge,
      :ult,
      :ule,
      :une,
      :uno,
      true
    ]

    @spec new(Types.destination(), operation(), operand(), operand()) :: __MODULE__.t()
    def new(dest, operation, op1, op2) when operation in @legal_ops do
      unless Type.float?(op1.type),
        do: raise("fcmp - operand-1 must be float typed, got #{inspect(op1.type)}!")

      unless Type.float?(op2.type),
        do: raise("fcmp - operand-2 must be float typed, got #{inspect(op2.type)}!")

      if op1.type != op2.type, do: raise("Unsupported attempt to mix types in fcmp!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        operation: operation,
        op1: op1,
        op2: op2
      }
    end
  end

  def fcmp(dest, operation, op1, op2), do: Fcmp.new(dest, operation, op1, op2)

  defmodule Fptrunc do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Float.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    @spec new(Types.destination(), Value.t(), Type.Float.t()) :: __MODULE__.t()
    def new(dest, src, to_type) do
      if !Type.float?(src.type), do: raise("Unsupported: fptrunc on non-float src!")
      if !Type.float?(to_type), do: raise("Unsupported: fptrunc to non-float type!")

      if Type.float_width(to_type) >= Type.float_width(src.type),
        do:
          raise(
            "Unsupported: fptrunc #{inspect(src.type)} -> #{inspect(to_type)} does not narrow!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def fptrunc(dest, src, to_type), do: Fptrunc.new(dest, src, to_type)

  defmodule Fpext do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Float.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    @spec new(Types.destination(), Value.t(), Type.Float.t()) :: __MODULE__.t()
    def new(dest, src, to_type) do
      if !Type.float?(src.type), do: raise("Unsupported: fpext on non-float src!")
      if !Type.float?(to_type), do: raise("Unsupported: fpext to non-float type!")

      if Type.float_width(to_type) <= Type.float_width(src.type),
        do:
          raise("Unsupported: fpext #{inspect(src.type)} -> #{inspect(to_type)} does not widen!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def fpext(dest, src, to_type), do: Fpext.new(dest, src, to_type)

  defmodule Fptosi do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Integer.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    @spec new(Types.destination(), Value.t(), Type.Integer.t()) :: __MODULE__.t()
    def new(dest, src, to_type) do
      if !Type.float?(src.type), do: raise("Unsupported: fptosi on non-float src!")
      if !Type.integer?(to_type), do: raise("Unsupported: fptosi to non-integer type!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def fptosi(dest, src, to_type), do: Fptosi.new(dest, src, to_type)

  defmodule Fptoui do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Integer.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    @spec new(Types.destination(), Value.t(), Type.Integer.t()) :: __MODULE__.t()
    def new(dest, src, to_type) do
      if !Type.float?(src.type), do: raise("Unsupported: fptoui on non-float src!")
      if !Type.integer?(to_type), do: raise("Unsupported: fptoui to non-integer type!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def fptoui(dest, src, to_type), do: Fptoui.new(dest, src, to_type)

  defmodule Freeze do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t()
          }
    defstruct [:id, :dest, :src]

    def new(dest, src) do
      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src
      }
    end
  end

  def freeze(dest, src), do: Freeze.new(dest, src)

  defmodule GetElementPtr do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            type: Type.t(),
            source: Value.t(),
            indices: [Value.t()],
            inbounds: boolean()
          }
    defstruct [:id, :dest, :type, :source, :indices, :inbounds]

    @spec new(Types.destination(), Type.t(), Value.t(), [Value.t()], keyword(atom())) ::
            __MODULE__.t()
    def new(dest, type, source, indices, opts \\ []) do
      inbounds = Keyword.get(opts, :inbounds, false)

      unless Enum.all?(indices, &integer_index?/1),
        do: raise("Unsupported non-integer index value!")

      unless Type.ptr?(source.type), do: raise("Source #{inspect(source)} must be pointer typed!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        type: type,
        source: source,
        indices: indices,
        inbounds: inbounds
      }
    end

    defp integer_index?(%Value.Integer{}), do: true
    defp integer_index?(%Value.LocalRef{type: %Type.Integer{}}), do: true
    defp integer_index?(%Value.Handle{type: %Type.Integer{}}), do: true
    defp integer_index?(_), do: false
  end

  def get_element_ptr(dest, type, source, indices, opts \\ []) when is_list(indices),
    do: GetElementPtr.new(dest, type, source, indices, opts)

  defmodule Icmp do
    @type operation :: atom()
    @type operand :: Value.t()
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            operation: operation(),
            op1: operand(),
            op2: operand()
          }
    defstruct [:id, :dest, :operation, :op1, :op2]

    @legal_ops [:eq, :ne, :ugt, :uge, :ult, :ule, :sgt, :sge, :slt, :sle]

    @spec new(Types.destination(), operation(), operand(), operand()) :: __MODULE__.t()
    def new(dest, operation, op1, op2) when operation in @legal_ops do
      if op1.type != Type.ptr() && !Type.integer?(op1.type),
        do: raise("Unsupported operand-1 type #{inspect(op1.type)}!")

      if op2.type != Type.ptr() && !Type.integer?(op2.type),
        do: raise("Unsupported operand-2 type #{inspect(op2.type)}!")

      if op1.type != op2.type, do: raise("Unsupported attempt to mix types in icmp!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        operation: operation,
        op1: op1,
        op2: op2
      }
    end
  end

  def icmp(dest, operation, op1, op2), do: Icmp.new(dest, operation, op1, op2)

  defmodule IndirectBr do
    @type t :: %__MODULE__{
            id: reference(),
            address: Value.t(),
            destinations: [Label.t()]
          }
    defstruct [:id, :address, :destinations]

    @spec new(Value.t(), destinations: [Label.t()]) :: __MODULE__.t()
    def new(address, destinations) do
      if !Type.ptr?(address.type), do: raise("indirectbr - address must be a pointer type!")
      if length(destinations) == 0, do: raise("indirectbr - requires at least one destination!")

      unless Enum.all?(destinations, &match?(%Label{}, &1)),
        do: raise("indirectbr - destinations must be labels!")

      %__MODULE__{
        id: make_ref(),
        address: address,
        destinations: destinations
      }
    end
  end

  def indirect_br(address, destinations), do: IndirectBr.new(address, destinations)

  defmodule InsertValue do
    alias Wyvern.Value

    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            aggregate: Value.t(),
            value: Value.t(),
            index_list: [non_neg_integer()]
          }
    defstruct [:id, :dest, :aggregate, :value, :index_list]

    @spec new(Types.destination(), Value.t(), Value.t(), [non_neg_integer()]) ::
            __MODULE__.t()
    def new(dest, aggregate, value, index_list) when is_list(index_list) do
      validate_index_list(index_list)
      validate_type(aggregate, value, index_list)

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        aggregate: aggregate,
        value: value,
        index_list: index_list
      }
    end

    defp validate_index_list(index_list) do
      if length(index_list) < 1, do: raise("insertvalue - must specify at least one index value!")

      unless Enum.all?(index_list, fn index -> is_integer(index) && index >= 0 end),
        do: raise("insertvalue - indexes must be non-negative integers!")
    end

    defp validate_type(aggregate, value, index_list) do
      field_type = Type.field_type(aggregate.type, index_list)

      if field_type != value.type,
        do: raise("insertvalue - field value disagrees with type value!")
    end
  end

  def insert_value(dest, aggregate, value, index_list),
    do: InsertValue.new(dest, aggregate, value, index_list)

  defmodule IntToPtr do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t()
          }
    defstruct [:id, :dest, :src]

    @spec new(Types.destination(), Value.t()) :: __MODULE__.t()
    def new(dest, src) do
      if !Type.integer?(src.type), do: raise("Attempt to convert a non-integer to pointer!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src
      }
    end
  end

  def int_to_ptr(dest, src), do: IntToPtr.new(dest, src)

  defmodule Load do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            type: Type.t(),
            src: Value.t()
          }
    defstruct [:id, :dest, :type, :src]

    @spec new(Types.destination(), Type.t(), Value.t()) :: __MODULE__.t()
    def new(dest, type, src) do
      if src.type != Type.ptr(), do: raise("Unsupported attempt to load from non-pointer!")
      %__MODULE__{id: make_ref(), dest: dest, type: type, src: src}
    end
  end

  def load(dest, type, src), do: Load.new(dest, type, src)

  defmodule Lshr do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("lshr - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "lshr - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def lshr(dest, op1, op2), do: Lshr.new(dest, op1, op2)

  defmodule Mul do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("mul - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "mul - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def mul(dest, op1, op2), do: Mul.new(dest, op1, op2)

  defmodule Or do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("or - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "or - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def bit_or(dest, op1, op2), do: Or.new(dest, op1, op2)

  defmodule Phi do
    @type incoming :: {Value.t(), Label.t()}
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            type: Type.t(),
            incoming: [incoming()]
          }
    defstruct [:id, :dest, :type, :incoming]

    @doc """
    Phi.new/3 validates that all incoming values share type, but does not validate that incoming's labels are actually the predecessor blocks of the block the Phi sits in (nor that every predecessor is covered exactly once).

    Doing that requires knowing the block's actual predecessors, which means walking the whole Function's blocks list to find which blocks end in a terminator targeting this block's label. We don't have that CFG-level analysis yet so it isn't checked here. Malformed phis (wrong/missing/duplicate predecessors) will produce syntactically valid but semantically broken LLVM IR (e.g. verifier will reject it) rather than raising during construction. We'll revisit this later.
    """
    @spec new(Types.destination(), Type.t(), [incoming()]) :: __MODULE__.t()
    def new(dest, type, incoming) when is_list(incoming) do
      if Enum.empty?(incoming), do: raise("Phi requires at least one incoming value!")

      if Enum.any?(incoming, fn {value, _label} -> value.type != type end),
        do: raise("Phi incoming value different to phi type!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        type: type,
        incoming: incoming
      }
    end
  end

  def phi(dest, type, incoming) when is_list(incoming), do: Phi.new(dest, type, incoming)

  defmodule PtrToInt do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Integer.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    @spec new(Types.destination(), Value.t(), Type.Integer.t()) :: __MODULE__.t()
    def new(dest, src, to_type) do
      if !Type.ptr?(src.type), do: raise("Cannot convert non-pointer value!")
      if !Type.integer?(to_type), do: raise("Cannot convert non-integer value!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def ptr_to_int(dest, src, to_type), do: PtrToInt.new(dest, src, to_type)

  defmodule Ret do
    @type val_type :: Value.t() | nil
    @type t :: %__MODULE__{
            id: reference(),
            value: val_type()
          }
    defstruct [:id, :value]

    @spec new(val_type()) :: __MODULE__.t()
    def new(value) do
      %__MODULE__{id: make_ref(), value: value}
    end
  end

  def ret(value), do: Ret.new(value)

  defmodule Sdiv do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("sdiv - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "sdiv - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def sdiv(dest, op1, op2), do: Sdiv.new(dest, op1, op2)

  defmodule Select do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            cond: Value.t(),
            if_true: Value.t(),
            if_false: Value.t()
          }
    defstruct [:id, :dest, :cond, :if_true, :if_false]

    def new(dest, cond, if_true, if_false) do
      unless cond.type == Type.i1(), do: raise("select - condition must be typed i1!")

      unless if_true.type == if_false.type,
        do: raise("select - if_true/if_false values must share the same type!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        cond: cond,
        if_true: if_true,
        if_false: if_false
      }
    end
  end

  def select(dest, cond, if_true, if_false), do: Select.new(dest, cond, if_true, if_false)

  defmodule Sext do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Integer.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    @spec new(Types.destination(), Value.t(), Type.Integer.t()) :: __MODULE__.t()
    def new(dest, src, to_type) do
      if !Type.integer?(src.type), do: raise("Unsupported: sext on non-integer source!")
      if !Type.integer?(to_type), do: raise("Unsupported: sext to non-integer type!")

      if to_type.width <= src.type.width,
        do: raise("Unsupported: sext #{src.type.width} -> #{to_type.width} does not widen!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def sext(dest, src, to_type), do: Sext.new(dest, src, to_type)

  defmodule Shl do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("shl - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "shl - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def shl(dest, op1, op2), do: Shl.new(dest, op1, op2)

  defmodule Sitofp do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Float.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    @spec new(Types.destination(), Value.t(), Type.Float.t()) :: __MODULE__.t()
    def new(dest, src, to_type) do
      if !Type.integer?(src.type), do: raise("Unsupported: sitofp on non-integer src!")
      if !Type.float?(to_type), do: raise("Unsupported: sitofp to non-float type!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def sitofp(dest, src, to_type), do: Sitofp.new(dest, src, to_type)

  defmodule Srem do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("srem - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "srem - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def srem(dest, op1, op2), do: Srem.new(dest, op1, op2)

  defmodule Store do
    @type t :: %__MODULE__{
            id: reference(),
            value: Value.t(),
            dest: Value.t()
          }
    defstruct [:id, :value, :dest]

    @spec new(Value.t(), Value.t()) :: __MODULE__.t()
    def new(value, dest) do
      if dest.type != Type.ptr(),
        do: raise("Unsupported store to non-pointer destination!")

      %__MODULE__{
        id: make_ref(),
        value: value,
        dest: dest
      }
    end
  end

  def store(value, dest), do: Store.new(value, dest)

  defmodule Sub do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("sub - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "sub - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def sub(dest, op1, op2), do: Sub.new(dest, op1, op2)

  defmodule Switch do
    @type t :: %__MODULE__{
            id: reference(),
            value: Value.t(),
            default_label: Label.t(),
            cases: [{Value.t(), Label.t()}]
          }
    defstruct [:id, :value, :default_label, :cases]

    @spec new(Value.t(), Label.t(), [{Value.t(), Label.t()}]) :: __MODULE__.t()
    def new(value, %Label{} = default_label, cases) when is_list(cases) do
      if !Type.integer?(value.type), do: raise("switch - unsupported on non-integer value!")

      if Enum.any?(cases, fn {case_value, _} ->
           !match?(%Value.Integer{}, case_value) || value.type != case_value.type
         end),
         do: raise("switch - invalid or non-integer types!")

      case_values = Enum.map(cases, fn {case_value, _} -> case_value.value end) |> Enum.uniq()
      if length(case_values) < length(cases), do: raise("switch - non-unique value!")

      unless Enum.all?(cases, fn
               {_, %Label{}} -> true
               _ -> false
             end),
             do: raise("switch - case label missing!")

      %__MODULE__{
        id: make_ref(),
        value: value,
        default_label: default_label,
        cases: cases
      }
    end
  end

  def switch(value, default_label, cases), do: Switch.new(value, default_label, cases)

  defmodule Trunc do
    alias Wyvern.Value

    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Integer.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    def new(dest, src, to_type) do
      if !Type.integer?(src.type), do: raise("Unsupported: trunc on non-integer src!")
      if !Type.integer?(to_type), do: raise("Unsupported: trunc to non-integer type!")

      if to_type.width >= src.type.width,
        do: raise("Unsupported: trunc #{src.type.width} -> #{to_type.width} does not narrow!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def trunc(dest, src, to_type), do: Trunc.new(dest, src, to_type)

  defmodule Udiv do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("udiv - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "udiv - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def udiv(dest, op1, op2), do: Udiv.new(dest, op1, op2)

  defmodule Uitofp do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Float.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    @spec new(Types.destination(), Value.t(), Type.Float.t()) :: __MODULE__.t()
    def new(dest, src, to_type) do
      if !Type.integer?(src.type), do: raise("Unsupported: uitofp on non-integer src!")
      if !Type.float?(to_type), do: raise("Unsupported: uitofp to non-float type!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def uitofp(dest, src, to_type), do: Uitofp.new(dest, src, to_type)

  defmodule Urem do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("urem - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "urem - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def urem(dest, op1, op2), do: Urem.new(dest, op1, op2)

  defmodule Unreachable do
    @type t :: %__MODULE__{
            id: reference()
          }
    defstruct [:id]

    def new() do
      %__MODULE__{id: make_ref()}
    end
  end

  def unreachable(), do: Unreachable.new()

  defmodule Xor do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            op1: Value.t(),
            op2: Value.t()
          }
    defstruct [:id, :dest, :op1, :op2]

    @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
    def new(dest, op1, op2) do
      unless Type.integer?(op1.type),
        do: raise("xor - operands must be integer typed, got #{inspect(op1.type)}!")

      if op1.type != op2.type,
        do:
          raise(
            "xor - different operand value types #{inspect(op1.type)} != #{inspect(op2.type)}!"
          )

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        op1: op1,
        op2: op2
      }
    end
  end

  def bit_xor(dest, op1, op2), do: Xor.new(dest, op1, op2)

  defmodule Zext do
    @type t :: %__MODULE__{
            id: reference(),
            dest: Types.destination(),
            src: Value.t(),
            to_type: Type.Integer.t()
          }
    defstruct [:id, :dest, :src, :to_type]

    @spec new(Types.destination(), Value.t(), Type.Integer.t()) :: __MODULE__.t()
    def new(dest, src, to_type) do
      if !Type.integer?(src.type), do: raise("Unsupported: zext on non-integer src!")
      if !Type.integer?(to_type), do: raise("Unsupport: zext to non-integer type!")

      if to_type.width <= src.type.width,
        do: raise("Unsupported: zext #{src.type.width} -> #{to_type.width} does not widen!")

      %__MODULE__{
        id: make_ref(),
        dest: dest,
        src: src,
        to_type: to_type
      }
    end
  end

  def zext(dest, src, to_type), do: Zext.new(dest, src, to_type)

  @doc """
  Returns true if this instruction is a "terminator" that legally ends an LLVM block.
  """
  def terminator?(%BR{}), do: true
  def terminator?(%IndirectBr{}), do: true
  def terminator?(%Ret{}), do: true
  def terminator?(%Switch{}), do: true
  def terminator?(%Unreachable{}), do: true
  def terminator?(_), do: false

  @type t ::
          Add.t()
          | Alloca.t()
          | And.t()
          | Ashr.t()
          | BR.t()
          | Call.t()
          | Fadd.t()
          | Fcmp.t()
          | Fdiv.t()
          | Fmul.t()
          | Fneg.t()
          | Fpext.t()
          | Fptosi.t()
          | Fptoui.t()
          | Fptrunc.t()
          | Frem.t()
          | Fsub.t()
          | Freeze.t()
          | GetElementPtr.t()
          | Icmp.t()
          | IndirectBr.t()
          | IntToPtr.t()
          | Load.t()
          | Lshr.t()
          | Mul.t()
          | Or.t()
          | Phi.t()
          | PtrToInt.t()
          | Ret.t()
          | Sdiv.t()
          | Select.t()
          | Sext.t()
          | Shl.t()
          | Sitofp.t()
          | Srem.t()
          | Store.t()
          | Sub.t()
          | Switch.t()
          | Trunc.t()
          | Udiv.t()
          | Uitofp.t()
          | Unreachable.t()
          | Urem.t()
          | Xor.t()
          | Zext.t()
end
