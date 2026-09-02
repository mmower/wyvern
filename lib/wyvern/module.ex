defmodule Wyvern.Module do
  @moduledoc """
  The Module structure represents a single LLVM module as a flat namespace of globals and functions.
  """
  alias Wyvern.IR
  alias Wyvern.Type
  alias Wyvern.Function
  alias Wyvern.Declaration
  alias Wyvern.GlobalVariable

  @valid_options [
    :globals,
    :declarations,
    :functions,
    :named_structs,
    :target_triple,
    :target_datalayout
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          source_path: String.t(),
          globals: [GlobalVariable.t()],
          declarations: [Declaration.t()],
          functions: [Function.t()],
          named_structs: [Type.NamedStruct.t()],
          target_triple: String.t(),
          target_datalayout: String.t()
        }
  defstruct [
    :name,
    :source_path,
    :globals,
    :declarations,
    :functions,
    :named_structs,
    :target_triple,
    :target_datalayout
  ]

  @spec new(String.t(), keyword()) :: __MODULE__.t()
  def new(name, source_path, opts \\ []) when is_binary(name) and is_list(opts) do
    validate_opts!(opts)

    globals = Keyword.get(opts, :globals, [])
    declarations = Keyword.get(opts, :declarations, [])
    functions = Keyword.get(opts, :functions, [])
    named_structs = Keyword.get(opts, :named_structs, [])
    target_triple = Keyword.get(opts, :target_triple)
    target_datalayout = Keyword.get(opts, :target_datalayout)

    if Enum.map(named_structs, & &1.name) |> Enum.uniq() |> Enum.count() !=
         Enum.count(named_structs),
       do: raise("Named struct names must be unique!")

    global_names = Enum.map(globals, & &1.name)
    decl_names = Enum.map(declarations, & &1.name)
    fun_names = Enum.map(functions, & &1.name)
    all_names = global_names ++ decl_names ++ fun_names

    duplicates =
      all_names -- Enum.uniq(all_names)

    if length(duplicates) > 0,
      do: raise("Conflict declaration and function names must be uniqe: #{inspect(duplicates)}!")

    %__MODULE__{
      name: name,
      source_path: source_path,
      globals: globals,
      declarations: declarations,
      functions: functions,
      named_structs: named_structs,
      target_triple: target_triple,
      target_datalayout: target_datalayout
    }
  end

  @spec to_ir(__MODULE__.t(), keyword()) :: String.t()
  def to_ir(
        %__MODULE__{
          globals: globals,
          declarations: declarations,
          functions: functions,
          named_structs: named_structs
        } = module,
        opts \\ []
      ) do
    suppress_header = Keyword.get(opts, :suppress_header, false)

    [
      header_ir(module, suppress_header),
      named_structs_to_ir(named_structs),
      globals_to_ir(globals),
      declarations_to_ir(declarations),
      functions_to_ir(functions)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp validate_opts!(opts) do
    unless Enum.all?(Keyword.keys(opts), fn opt -> opt in @valid_options end),
      do: raise("Invalid option specified!")
  end

  defp header_ir(_module, true), do: ""

  defp header_ir(
         %__MODULE__{
           name: name,
           source_path: source_path,
           target_triple: target_triple,
           target_datalayout: target_datalayout
         },
         false
       ) do
    target_triple = if target_triple, do: ~s(\ntarget triple = "#{target_triple}"), else: ""

    target_datalayout =
      if target_datalayout, do: ~s(\ntarget datalayout = "#{target_datalayout}"), else: ""

    """
    ; ModuleID=#{name}
    source_filename=#{source_path}#{target_triple}#{target_datalayout}
    """
  end

  defp globals_to_ir(globals) do
    Enum.map_join(globals, "\n", fn global ->
      {global_str, _} = IR.to_ir(global, IR.resolve_names(global, IR.Context.new()))
      global_str
    end)
  end

  defp declarations_to_ir(declarations) do
    Enum.map_join(declarations, "\n", fn decl ->
      {decl_str, _} = IR.to_ir(decl, IR.Context.new())
      decl_str
    end)
  end

  defp functions_to_ir(functions) do
    Enum.map_join(functions, "\n\n", fn fun ->
      {fun_str, _} = IR.to_ir(fun, IR.resolve_names(fun, IR.Context.new()))
      fun_str
    end)
  end

  defp named_structs_to_ir(named_structs) do
    Enum.map_join(named_structs, "\n", fn %Type.NamedStruct{
                                            name: name,
                                            fields: fields,
                                            packed: packed
                                          } ->
      {struct_ir, _} = IR.to_ir(Type.struct(fields, packed: packed), IR.Context.new())
      "%#{name} = type #{struct_ir}"
    end)
  end
end
