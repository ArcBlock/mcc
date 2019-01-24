ExUnit.start()

Application.stop(:mnesia)
Application.stop(:mcc)
Application.put_env(:mcc, :mnesia_table_modules, [MccTest.Support.Cache])
Application.start(:mcc)

MccTest.Support.Cache.start_expiration_process()
