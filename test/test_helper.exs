{:ok, redis} = Redix.start_link database: 13
Process.register(redis, :r)
ExUnit.start()
