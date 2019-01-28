defmodule MccTest do
  use ExUnit.Case
  alias MccTest.Support.Table.Account, as: TableAccount

  setup_all do
    Mcc.start()
    MccTest.Support.AccountFile.init_file()
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
    assert :"$not_can_found" == TableAccount.get_with_ttl("id2")
  end

  test "test put and get, with auto ttl" do
    TableAccount.put_with_ttl("id3", %{id: "id3", name: "name3"}, 1)
    Process.sleep(3000)
    assert :"$not_can_found" == TableAccount.get_with_ttl("id3")
  end

  test "ttl for size limit" do
    for i <- 1..100 do
      TableAccount.put_with_ttl("id_auto_#{i}", %{id: "id_auto_#{i}"})
    end

    Process.sleep(3000)
    assert TableAccount.table_info(:size) <= 70
  end

  test "check cache before" do
    assert "info_file_1" ==
             Mcc.check_cache_before(MccTest.Support.AccountFile, :get_account, ["id_file_1"],
               cache_key: "id_file_1",
               cache_mod: TableAccount,
               read_cache_func: :get_with_ttl
             )

    assert "info_file_1" ==
             Mcc.check_cache_before(MccTest.Support.AccountFile, :get_account, ["id_file_1"],
               cache_key: "id_file_1",
               cache_ttl: 10,
               cache_mod: TableAccount,
               read_cache_func: :get_with_ttl
             )

    assert "info_file_1" ==
             Mcc.check_cache_before(MccTest.Support.AccountFile, :get_account, ["id_file_1"],
               cache_key: "id_file_1",
               cache_mod: TableAccount,
               read_cache_func: :get_with_ttl,
               write_back: true,
               write_cache_func: :put_with_ttl
             )

    assert %{user_profile: "info_file_1"} =
             Mcc.check_cache_before(MccTest.Support.AccountFile, :get_account, ["id_file_1"],
               cache_key: "id_file_1",
               cache_ttl: 10,
               cache_mod: TableAccount,
               read_cache_func: :get_with_ttl,
               write_back: true,
               write_cache_func: :put_with_ttl
             )

    assert "info_file_2" ==
             Mcc.check_cache_before(MccTest.Support.AccountFile, :get_account, ["id_file_2"],
               cache_key: "id_file_2",
               cache_ttl: 10,
               cache_mod: TableAccount,
               read_cache_func: :get_with_ttl,
               write_back: true,
               write_cache_func: :put_with_ttl
             )
  end

  # __end_of_module__
end
