defmodule Example.PureWithProtocolImpl do
  @moduledoc """
  Has a protocol implementation
  """
  use Example.PureModuleMarker

  defstruct [:field]

  def f1 do
    Map.new()
  end

  defimpl Example.My.Protocol do
    def f(v), do: v.field
  end
end
