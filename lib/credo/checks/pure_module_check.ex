defmodule Credo.Check.Custom.PureModule do
  @moduledoc """
    Checks that modules marked with `use PureModule` only depend on
    other pure modules

    Can use `use PureModule, force: true` to force a module to
    be marked as pure when it is not

    You need to define the PureModule marker somewhere in your code:
    ```
    defmodule PureModule do
      @moduledoc "Marker for credo_pure_check"
      defmacro __using__(_opts) do
        # No need to do anything as we just look for the `use` marker
      end
    end
    ```

    You can change the name using the `pure_mod_marker` parameter.

    This is not included in the library as otherwise this library and credo
    (as a dependency of this library) would have to be a dependency for all
    mix environments.
  """

  @explanation [
    check: @moduledoc,
    params: [
      pure_mod_marker: """
      Marker to use to indicate a module is pure e.g. `PureModule`
      by adding
      `use PureModule` in the module
      """,
      stdlib_pure_mods: """
      List of Elixir stdlib modules that are considered pure. This is already set to a default
      """,
      extra_pure_mods: """
        List of pure modules in dependencies you are using
      """
    ]
  ]
  @default_params [
    # our check will find this line.
    # Exceptions
    # Dubiously pure modules
    # Common libs
    pure_mod_marker: PureModule,
    stdlib_pure_mods:
      ~w[Enum Map MapSet String List Logger Keyword Float Regex Integer] ++
        ~w[ArgumentError CompileError] ++
        ~w[Module Macro Application],
    extra_pure_mods: []
  ]

  # you can configure the basics of your check via the `use Credo.Check` call
  use Credo.Check, base_priority: :high, category: :custom

  defmodule ModuleState do
    defstruct [:issue_meta, :deps, :force?, marked_pure?: false]
  end

  defmodule Context do
    defstruct [
      # Marker in form of [:Pure, :Module, :Marker]
      :pure_marker_list,
      # Marker in form of string "Pure.Module.Marker"
      :pure_marker_string,
      # The ast for the file being parsed
      :source_ast
    ]
  end

  @impl true
  def run_on_all_source_files(exec, source_files, params) do
    lib_pure_mods =
      Params.get(params, :stdlib_pure_mods, __MODULE__) ++
        Params.get(params, :extra_pure_mods, __MODULE__)

    pure_mod_marker = Params.get(params, :pure_mod_marker, __MODULE__)

    context = %Context{
      pure_marker_list: mod_to_atoms(pure_mod_marker),
      pure_marker_string: mod_to_string(pure_mod_marker)
    }

    source_files
    |> Enum.reduce(%{}, fn %Credo.SourceFile{} = source_file, acc ->
      source_ast = Credo.SourceFile.ast(source_file)

      Credo.Code.prewalk(
        source_file,
        fn ast, acc ->
          traverse(
            ast,
            %Context{context | source_ast: source_ast},
            acc,
            IssueMeta.for(source_file, params)
          )
        end,
        acc
      )
    end)
    |> create_issues(lib_pure_mods)
    |> (fn issues -> Credo.Execution.set_issues(exec, issues) end).()

    :ok
  end

  # Converts a module name to list of atoms e.g. Foo.Bar -> [:Foo, :Bar]
  defp mod_to_atoms(mod) do
    mod |> Module.split() |> Enum.map(&String.to_atom(&1))
  end

  # Converts a module name to a string e.g. Foo.Bar -> "Foo.Bar"
  defp mod_to_string(mod) do
    mod |> Module.split() |> Enum.join(".")
  end

  defp traverse(
         {:defmodule, [line, _column], _} = ast,
         %Context{source_ast: source_ast, pure_marker_string: pure_marker_string},
         acc,
         issue_meta
       ) do
    # Need to get the full module name by resolving it within the scope of the
    # ast in case it is a submodule
    {:defmodule, mod_full_name} = Credo.Code.Scope.name(source_ast, [line])

    mod_deps = get_dependencies(ast)

    acc =
      Map.put(acc, mod_full_name, %ModuleState{
        issue_meta: issue_meta,
        deps: Enum.reject(mod_deps, &(&1 == pure_marker_string))
      })

    {ast, acc}
  end

  # Look for pure marker
  defp traverse(
         {:use, [line, _column],
          [
            {:__aliases__, _alias_position, pure_marker_list} | opts
          ]} = ast,
         %Context{source_ast: source_ast, pure_marker_list: pure_marker_list},
         acc,
         _issue_meta
       ) do
    force? =
      case opts do
        [] -> false
        [opts] -> Keyword.get(opts, :force, false)
      end

    {:defmodule, mod_full_name} = Credo.Code.Scope.name(source_ast, [line])

    acc =
      Map.update!(acc, mod_full_name, fn ms ->
        %ModuleState{ms | marked_pure?: true, force?: force?}
      end)

    {ast, acc}
  end

  # Mark all protocol definitions as pure so when we see an alias
  # to a protocol it is not marked as impure
  # However, if a pure module has an impure implementation of a protocol
  # then it will fail the check
  defp traverse(
         {:defprotocol, _position, _} = ast,
         _context,
         acc,
         issue_meta
       ) do
    mod_name = protocol_name(ast)

    acc =
      Map.put(acc, mod_name, %ModuleState{
        issue_meta: issue_meta,
        deps: [],
        marked_pure?: true
      })

    {ast, acc}
  end

  # Everything else we just skip
  defp traverse(
         ast,
         _context,
         acc,
         _issue_meta
       ) do
    {ast, acc}
  end

  # Copied from Credo.Code.Module.name/1
  defp protocol_name({:defprotocol, _, [{:__aliases__, _, name_list}, _]}) do
    name_list
    |> Enum.map(&Credo.Code.Module.name/1)
    |> Enum.join(".")
  end

  defp create_issues(module_map, lib_mods) do
    pure_module_map =
      module_map
      |> Enum.filter(fn {_name, %ModuleState{marked_pure?: p?}} -> p? end)
      |> Map.new()

    pure_module_map
    |> Enum.reject(fn {_name, %ModuleState{force?: f?}} -> f? end)
    |> Enum.reduce([], fn {name, %ModuleState{issue_meta: issue_meta, deps: deps}}, acc ->
      deps
      |> Enum.reject(fn dep ->
        pure_mod?(dep, Map.keys(pure_module_map), lib_mods)
      end)
      |> case do
        [] -> acc
        impure_deps -> [issue(name, impure_deps, issue_meta) | acc]
      end
    end)
  end

  defp pure_mod?(mod, project_mods, lib_mods) do
    Enum.member?(project_mods, mod) or
      Enum.any?(lib_mods, fn lib_mod ->
        if String.ends_with?(lib_mod, ".*") do
          String.starts_with?(mod, String.slice(lib_mod, 0..-2))
        else
          mod == lib_mod
        end
      end) or
      String.starts_with?(mod, "unquote(")
  end

  defp get_dependencies(ast) do
    aliases = Credo.Code.Module.aliases(ast)

    ast
    |> Credo.Code.Module.modules()
    |> with_fullnames(aliases)
  end

  # Resolve dependencies to full module names
  defp with_fullnames(dependencies, aliases) do
    dependencies
    |> Enum.map(&full_name(&1, aliases))
    |> Enum.uniq()
  end

  # Get full module name from list of aliases (if present)
  defp full_name(dep, aliases) do
    [dep_prefix | dep_suffix] = String.split(dep, ".", parts: 2)

    aliases
    |> Enum.find(&String.ends_with?(&1, dep_prefix))
    |> case do
      nil ->
        dep

      full_name ->
        case dep_suffix do
          [] -> full_name
          [suffix] -> "#{full_name}.#{suffix}"
        end
    end
  end

  defp issue(name, impure_deps, issue_meta) do
    format_issue(
      issue_meta,
      message:
        "Module #{name} marked as pure but has impure dependencies: #{inspect(impure_deps)}"
      # line_no: meta[:line],
      # column_no: meta[:column]
    )
  end
end
