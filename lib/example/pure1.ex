defmodule Example.Pure1 do
  @moduledoc """
  foo
  """
  use Example.PureModuleMarker

  alias Example.Pure

  def f2 do
    Map.new()
  end

  def f1 do
    Pure.Two.f1()
  end
end
