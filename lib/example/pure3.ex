defmodule Example.Pure3 do
  @moduledoc """
  foo
  """

  # use Example.PureModuleMarker
  defmodule SubModule1 do
    use Example.PureModuleMarker

    def(f1) do
      123
    end
  end

  def f1 do
    Example.Impure1.f1()
  end

  def f2 do
    DateTime.utc_now()
  end

  def f3 do
    Map.new()
  end
end
