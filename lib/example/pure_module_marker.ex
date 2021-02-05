defmodule Example.PureModuleMarker do
  defmacro __using__(_opts) do
    # No need to do anything as we just look for the `use` marker
  end
end
