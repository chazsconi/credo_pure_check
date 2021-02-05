defmodule Example.Impure1 do
  use Example.PureModuleMarker, force: true

  def f1 do
    DateTime.utc_now()
  end
end
