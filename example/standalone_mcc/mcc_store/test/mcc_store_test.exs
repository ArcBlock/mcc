defmodule MccStoreTest do
  use ExUnit.Case
  doctest MccStore

  test "greets the world" do
    assert MccStore.hello() == :world
  end
end
