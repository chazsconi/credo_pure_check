defmodule Credo.Check.Custom.PureModule do
  @moduledoc """
    Checks that modules marked with `use Credo.Check.Custom.PureModule` only depend on
    other pure modules
  """

  @explanation [
    check: @moduledoc,
    params: [
      regex: "All lines matching this Regex will yield an issue."
    ]
  ]
  @default_params [
    # our check will find this line.
    # Exceptions
    # Dubiously pure modules
    # Common libs
    pure_stdlib_mods:
      ~w[Enum Map String List Logger Keyword Float Regex Integer] ++
        ~w[ArgumentError CompileError] ++
        ~w[Module Macro Application] ++
        ~w[Ecto.Schema Ecto.Changeset Poison.Encoder Poison.Encoder.Map] ++
        ~w[Kazan.Models.* Kazan.Apis.*]
  ]

  # you can configure the basics of your check via the `use Credo.Check` call
  use Credo.Check, base_priority: :high, category: :custom

  defmodule State do
    defstruct [:issue_meta, :deps]
  end

  @impl true
  def run_on_all_source_files(exec, source_files, params) do
    pure_stdlib_mods = Params.get(params, :pure_stdlib_mods, __MODULE__)

    source_files
    |> Enum.reduce(%{}, fn source_file, acc ->
      source_file
      |> Credo.Code.prewalk(&traverse(&1, &2, IssueMeta.for(source_file, params)), acc)
    end)
    |> create_issues(pure_stdlib_mods)
    |> (fn issues -> Credo.Execution.set_issues(exec, issues) end).()

    :ok
  end

  defp traverse(
         {:defmodule, _position, _} = ast,
         acc,
         issue_meta
       ) do
    pure_marker = "Credo.Check.Custom.PureModule"
    mod_name = Credo.Code.Module.name(ast)
    mod_deps = get_dependencies(ast)
    Credo.Code.Module.aliases(ast)

    acc =
      if pure_marker in mod_deps do
        Map.put(acc, mod_name, %State{
          issue_meta: issue_meta,
          deps: Enum.reject(mod_deps, &(&1 == pure_marker))
        })
      else
        acc
      end

    {ast, acc}
  end

  defp traverse(
         ast,
         acc,
         _issue_meta
       ) do
    {ast, acc}
  end

  defp create_issues(module_map, lib_mods) do
    module_map
    |> Enum.reduce([], fn {name, %State{issue_meta: issue_meta, deps: deps}}, acc ->
      deps
      |> Enum.reject(fn dep ->
        pure_mod?(dep, Map.keys(module_map), lib_mods)
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
    aliases
    |> Enum.find(&String.ends_with?(&1, dep))
    |> case do
      nil -> dep
      full_name -> full_name
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

  defmacro __using__(_opts) do
    # No need to do anything as we just look for the `use` marker
  end
end
