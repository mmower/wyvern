defmodule Wyvern.Type.Guards do
  alias Wyvern.Type.{Array, Float, Function, Integer, NamedStruct, Pointer, Struct, Void}

  defguard is_llvm_type(t)
           when is_struct(t, Integer) or is_struct(t, Float) or is_struct(t, Pointer) or
                  is_struct(t, Array) or is_struct(t, Function) or is_struct(t, Struct) or
                  is_struct(t, NamedStruct) or is_struct(t, Void)
end
