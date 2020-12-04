defmodule Example.Pure3 do
  @moduledoc """
  foo
  """
  use Credo.Check.Custom.PureModule

  defmodule SubModule1 do
    use Credo.Check.Custom.PureModule

    def f1 do
      DateTime.utc_now()
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
