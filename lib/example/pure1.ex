defmodule Example.Pure1 do
  @moduledoc """
  foo
  """
  use Credo.Check.Custom.PureModule

  alias Example.Pure2

  def f2 do
    Map.new()
  end

  def f1 do
    Pure2.f1()
  end
end
