defmodule MccTest do
  use ExUnit.Case
  alias MccTest.Support.Table.Account, as: TableAccount

  setup_all do
    Mcc.start()
  end

  test "test put and get" do
    TableAccount.put_with_ttl("id1", %{id: "id1", name: "name1"})

    assert %MccTest.Support.Table.Account{
             id: "id1",
             user_profile: %{id: "id1", name: "name1"}
           } = TableAccount.get_with_ttl("id1")
  end

  test "test put and get, with set ttl" do
    TableAccount.put_with_ttl("id2", %{id: "id2", name: "name2"}, 0)
    Process.sleep(1000)
    assert is_nil(TableAccount.get_with_ttl("id2"))
  end

  test "test put and get, with auto ttl" do
    TableAccount.put_with_ttl("id3", %{id: "id3", name: "name3"}, 1)
    Process.sleep(3000)
    assert is_nil(TableAccount.get_with_ttl("id3"))
  end

  test "ttl for size limit" do
    for i <- 1..100 do
      TableAccount.put_with_ttl("id_auto_#{i}", %{id: "id_auto_#{i}"})
    end

    Process.sleep(3000)
    assert TableAccount.table_info(:size) <= 70
  end

  # __end_of_module__
end
