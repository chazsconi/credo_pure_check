defmodule Example.PureWithDateTime do
  @moduledoc """
  foo
  """
  use Example.PureModuleMarker

  def f1 do
    if 1 == 2 do
      DateTime.from_iso8601("foo")
    end
  end

  def f2 do
    # DateTime.utc_now()
  end
end
