# Credo Pure Check

A custom Credo check to verify that modules marked with `use PureModule` only depend on
other pure modules.

## Installation

### Dependency

Install the library

```elixir
def deps do
  [
    {:credo_pure_check, github: "chazsconi/credo_pure_check", only: [:dev, :test], runtime: false}
  ]
end
```

### Add PureModule marker

You need to define the PureModule marker somewhere in your code:
```elixir
defmodule PureModule do
  @moduledoc "Marker for credo_pure_check"
  defmacro __using__(_opts) do
    # No need to do anything as we just look for the `use` marker
  end
end
```
This is not included in the library as otherwise this library and credo
(as a dependency of this library) would have to be a dependency for all
mix environments, not just `:dev` and `:test`.

You can change the name using the `pure_mod_marker` parameter.

### Add to .credo.exs

Update your `.credo.exs` to include the check. e.g.
```elixir
checks: [
  ...
  {Credo.Check.Custom.PureModule, extra_pure_mods: [Ecto.Schema, Ecto.Changeset]}
  ...
]
```

## Configuration

You can add 3rd party library modules that you consider as pure using the `extra_pure_mods` parameter.

Most Elixir standard library pure functions are also included but this can be changed via the `stdlib_pure_mods`
parameter.  This list currently includes `Logger` which is not really pure, as it has side effects, but is included
for pragmatism.  `DateTime` is not included as `DateTime.utc_now()` is not a pure function.  This is a TODO (see below).

# TODO

* Allow functions in modules as pure/impure e.g. `DateTime.utc_now()`
* Handle aliases added via a `use Foo` - perhaps by using postwalk
* Handle aliases with an `:as`
* Check erlang modules also work e.g. crypto library