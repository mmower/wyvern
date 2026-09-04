defmodule Wyvern.Value.Guards do
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

  defguard is_llvm_value(v)
           when is_struct(v, Array) or is_struct(v, BlockAddress) or is_struct(v, Integer) or
                  is_struct(v, Float) or is_struct(v, LocalRef) or is_struct(v, GlobalRef) or
                  is_struct(v, Handle) or is_struct(v, Poison) or is_struct(v, Struct) or
                  is_struct(v, Undef) or is_struct(v, Void)
end
