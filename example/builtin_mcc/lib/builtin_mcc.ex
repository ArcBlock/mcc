defmodule BuiltinMcc do
  @moduledoc """
  Documentation for BuiltinMcc.
  """

  alias BuiltinMcc.Table.AWithExp

  def test_table_a_with_exp do
    IO.puts("put one key pair: `{k1, v1}`, and ttl is 1")
    AWithExp.put_with_ttl(:k1, :v1, 1)
    IO.puts("get the key pair for `k1`")
    IO.puts("the cache data for key `k1` is: #{inspect(AWithExp.check_cache_data(:k1))}")
    IO.puts("sleep 1 second...")
    Process.sleep(1000)
    IO.puts("the value for key `k1` is: #{inspect(AWithExp.get_with_ttl(:k1))}")
    IO.puts("===========================================")
    IO.puts("put one key pair: `{k2, v2}`, and ttl is 2")
    AWithExp.put_with_ttl(:k2, :v2, 2)
    IO.puts("get the key pair for `k2`")
    IO.puts("the cache data for key `k2` is: #{inspect(AWithExp.check_cache_data(:k2))}")
    IO.puts("sleep 1 second...")
    Process.sleep(1000)
    IO.puts("the value for key `k1` is: #{inspect(AWithExp.get_with_ttl(:k2, 2))}")
    IO.puts("the cache data for key `k1` is: #{inspect(AWithExp.check_cache_data(:k2))}")
  end
end
