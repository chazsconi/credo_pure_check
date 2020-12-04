defmodule Example.Pure2 do
  @moduledoc """
  foo
  """
  use Credo.Check.Custom.PureModule

  def f1 do
    1
  end
end
