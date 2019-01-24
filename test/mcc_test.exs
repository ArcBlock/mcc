defmodule MccTest do
  use ExUnit.Case
  doctest Mcc

  test "greets the world" do
    assert Mcc.hello() == :world
  end
end
