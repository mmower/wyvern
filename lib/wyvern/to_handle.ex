defprotocol Wyvern.ToHandle do
  alias Wyvern.Value.Handle
  alias Wyvern.Instruction

  @spec to_handle(Instruction.t()) :: Handle.t()
  def to_handle(instruction)
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Add do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Add{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Alloca do
  alias Wyvern.Type
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Alloca{id: id}) do
    Handle.new(id, Type.ptr())
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.And do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.And{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Ashr do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Ashr{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.BR do
  def to_handle(_), do: raise("ToHandle not supported in br!")
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Call do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Call{fn_type: %{ret_type: %Wyvern.Type.Void{}}}) do
    raise "ToHandle not supported in void call!"
  end

  def to_handle(%Wyvern.Instruction.Call{id: id, fn_type: %{ret_type: ret_type}}) do
    Handle.new(id, ret_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.ExtractValue do
  alias Wyvern.Value.Handle
  alias Wyvern.Instruction

  def to_handle(%Instruction.ExtractValue{id: id, value_type: value_type}) do
    Handle.new(id, value_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fadd do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fadd{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fsub do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fsub{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fmul do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fmul{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fneg do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fneg{id: id, src: src}) do
    Handle.new(id, src.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fdiv do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fdiv{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Frem do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Frem{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fcmp do
  alias Wyvern.Type
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fcmp{id: id}) do
    Handle.new(id, Type.i1())
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fptrunc do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fptrunc{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fpext do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fpext{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fptosi do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fptosi{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fptoui do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fptoui{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Freeze do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Freeze{id: id, src: src}) do
    Handle.new(id, src.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.GetElementPtr do
  alias Wyvern.Type
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.GetElementPtr{id: id}) do
    Handle.new(id, Type.ptr())
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Icmp do
  alias Wyvern.Type
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Icmp{id: id}) do
    Handle.new(id, Type.i1())
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.InsertValue do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.InsertValue{id: id, aggregate: aggregate}) do
    Handle.new(id, aggregate.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.IntToPtr do
  alias Wyvern.Type
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.IntToPtr{id: id}) do
    Handle.new(id, Type.ptr())
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Load do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Load{id: id, type: type}) do
    Handle.new(id, type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Lshr do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Lshr{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Mul do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Mul{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Or do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Or{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Phi do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Phi{id: id, type: type}) do
    Handle.new(id, type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.PtrToInt do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.PtrToInt{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Ret do
  def to_handle(_), do: raise("ToHandle not supported in ret!")
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Sdiv do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Sdiv{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Select do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Select{id: id, if_true: if_true}) do
    Handle.new(id, if_true.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Sext do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Sext{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Shl do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Shl{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Sitofp do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Sitofp{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Srem do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Srem{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Store do
  def to_handle(_), do: raise("ToHandle not supported in store!")
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Sub do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Sub{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Switch do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Switch{}) do
    raise "Unsupported - cannot take a handle on a switch!"
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Trunc do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Trunc{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Udiv do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Udiv{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Uitofp do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Uitofp{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Urem do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Urem{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Unreachable do
  def to_handle(%Wyvern.Instruction.Unreachable{}) do
    raise "Unsupported - cannot get a handle for unreachable!"
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Xor do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Xor{id: id, op1: op1}) do
    Handle.new(id, op1.type)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Zext do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Zext{id: id, to_type: to_type}) do
    Handle.new(id, to_type)
  end
end
