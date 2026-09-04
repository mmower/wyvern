# Wyvern 1.0.7

Author: Matt Mower <self@mattmower.com>

Creating LLVM IR can be a tedious and error prone task using strings and interpolation.

Wyvern exists to make it simpler.

It takes a builder approach allowing you to create a data structure representing the desired IR and then serialise to a string at the end.

## License

Published under the Apache License v2.0 (see LICENSE.txt)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `wyvern` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:wyvern, "~> 1.0.0"}
  ]
end
```

## Status

Wyvern does not represent a complete LLVM IR but rather the working set required for Project Aura, i.e. converting an Elixir module to LLVM IR.

## IR Example

The following builds the IR equivalent of a tiny Elixir module with a single
function that prints `"Hello world!"` and exits:

```elixir
defmodule Hello do
  def main, do: IO.puts("Hello world!")
end
```

```elixir
alias Wyvern.Module
alias Wyvern.Function
alias Wyvern.BasicBlock
alias Wyvern.Instruction
alias Wyvern.Declaration
alias Wyvern.GlobalVariable
alias Wyvern.Label
alias Wyvern.Type
alias Wyvern.Value

# Declare the external C function we want to call: i32 @puts(ptr)
puts_type = Type.function(Type.i32(), [Type.ptr()], false)
puts_decl = Declaration.new("puts", puts_type)

# A private, constant global holding the bytes of "Hello world!" plus a
# trailing NUL terminator, since LLVM has no native string type.
message =
  (String.to_charlist("Hello world!") ++ [0])
  |> Enum.map(&Value.i8/1)
  |> then(&Value.array(Type.i8(), &1))

message_global =
  GlobalVariable.new("message", message, mutable: false, linkage: :private, addr: :unnamed_addr)

# main's single basic block: call puts(message), then return 0
call_ins =
  Instruction.call(nil, puts_type, Value.global_ref("puts"), [Value.global_ref("message")])

ret_ins = Instruction.ret(Value.i32(0))
entry = BasicBlock.new(Label.new(), [call_ins, ret_ins])

main_fn = Function.new("main", Type.i32(), [], [entry])

mod =
  Module.new("hello", "hello.ex",
    declarations: [puts_decl],
    globals: [message_global],
    functions: [main_fn]
  )

IO.puts(Module.to_ir(mod))
```

This produces:

```llvm
; ModuleID=hello
source_filename=hello.ex

@message = private unnamed_addr constant [13 x i8] [i8 72, i8 101, i8 108, i8 108, i8 111, i8 32, i8 119, i8 111, i8 114, i8 108, i8 100, i8 33, i8 0]

declare i32 @puts(ptr)

define i32 @main() {
0:
  %1 = call i32 @puts(ptr @message)
  ret i32 0
}
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/wyvern>.

## AI Disclosure

The author used Claude Code as a research partner to explore and understand the LLVM spec and for routine coding tasks.

All code was written first by the author. Claude Code was used for refactorings (e.g. converting repetitive binary operations to use a shared helper function) and to build repetitive code sections once the pattern was established.

Claude Code was also used as the arbiter of the LLVM specification and to review the code against to ensure it was generating valid LLVM IR.