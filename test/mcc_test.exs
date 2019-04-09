defmodule MccTest do
  use ExUnit.Case
  alias MccTest.Support.Table.Account, as: TableAccount
  alias MccTest.Support.Table.DynamicAccount

  @dynamic_table_name :d_account_1

  setup_all do
    Mcc.start()
    MccTest.Support.AccountFile.init_file()
    DynamicAccount.create_table(@dynamic_table_name)
  end

  defp wait_for_can_found(mod, func, args) do
    case apply(mod, func, args) do
      :"$not_can_found" ->
        Process.sleep(100)
        wait_for_can_found(mod, func, args)

      other ->
        other
    end
  end

  test "test put and get" do
    TableAccount.rpc_put_with_ttl("id1", %{id: "id1", name: "name1"}, 100)

    assert %MccTest.Support.Table.Account{
             id: "id1",
             user_profile: %{id: "id1", name: "name1"}
           } = wait_for_can_found(TableAccount, :rpc_get_with_ttl, ["id1"])
  end

  test "test put and get for dynamic table which created manually" do
    DynamicAccount.put_with_ttl(@dynamic_table_name, "id1", %{id: "id1", name: "name1"}, 100)

    assert %DynamicAccount{id: "id1", user_profile: %{id: "id1", name: "name1"}} =
             DynamicAccount.get_with_ttl(@dynamic_table_name, "id1")
  end

  test "test put and get, with set ttl" do
    TableAccount.put_with_ttl("id2", %{id: "id2", name: "name2"}, 0)
    Process.sleep(1000)
    assert :"$not_can_found" == TableAccount.get_with_ttl("id2")
  end

  test "test put and get, with set ttl for dynamic table which created manually" do
    DynamicAccount.put_with_ttl(@dynamic_table_name, "id2", %{id: "id2", name: "name2"}, 0)
    Process.sleep(1000)
    assert :"$not_can_found" == DynamicAccount.get_with_ttl(@dynamic_table_name, "id2")
  end

  test "test put and get, with auto ttl" do
    TableAccount.put_with_ttl("id3", %{id: "id3", name: "name3"}, 1)
    Process.sleep(3000)
    assert :"$not_can_found" == TableAccount.get_with_ttl("id3")
  end

  test "test put and get, with auto ttl for dynamic table which created manually" do
    DynamicAccount.put_with_ttl(@dynamic_table_name, "id3", %{id: "id3", name: "name3"}, 1)
    Process.sleep(3000)
    assert :"$not_can_found" == DynamicAccount.get_with_ttl(@dynamic_table_name, "id3")
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

    assert (case(
              Mcc.check_cache_before(MccTest.Support.AccountFile, :get_account, ["id_file_1"],
                cache_key: "id_file_1",
                cache_ttl: 10,
                cache_mod: TableAccount,
                read_cache_func: :get_with_ttl,
                write_back: true,
                write_cache_func: :put_with_ttl
              )
            ) do
              %{user_profile: "info_file_1"} -> true
              "info_file_1" -> true
            end)

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
