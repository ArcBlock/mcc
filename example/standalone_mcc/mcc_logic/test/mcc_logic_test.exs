defmodule MccLogicTest do
  use ExUnit.Case
  doctest MccLogic

  test "greets the world" do
    assert MccLogic.hello() == :world
  end
end
