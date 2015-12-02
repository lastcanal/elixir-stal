Stal
====

Set algebra solver for Redis inspired by Soveran's [ruby
implimentation][stal].

Description
-----------

`Stal` receives an list with an s-expression composed of commands
and key names and resolves the set operations in [Redis][redis].


Getting started
---------------

Install [Redis][redis]. On most platforms it's as easy as grabbing
the sources, running make and then putting the `redis-server` binary
in the PATH.

Once you have it installed, you can execute `redis-server` and it
will run on `localhost:6379` by default. Check the `redis.conf`
file that comes with the sources if you want to change some settings.

Usage
-----

`Stal` requires a [Redix][redix] or [Eredis][eredis] client. To make things
easier, `Redix` is listed as a runtime dependency so the examples
in this document will work.

```elixir
# Connect the client to the default host
{:ok, redis} = Redix.start_link

# Use the Redis client to populate some sets
Redix.command(redis, ["SADD", "foo", "a", "b", "c"])
Redix.command(redis, ["SADD", "bar", "b", "c", "d"])
Redix.command(redis, ["SADD", "baz", "c", "d", "e"])
Redix.command(redis, ["SADD", "qux", "x", "y", "z"])
```

Now we can perform some set operations with `Stal`:

```elixir
expr = [:SUNION, "qux", [:SDIFF, [:SINTER, "foo", "bar"], "baz"]]

Stal.solve(redis, expr)
#=> {:ok, ["b", "x", "y", "z"]}
```

`Stal` translates the internal calls to  `:SUNION`, `:SDIFF` and
`:SINTER` into `SDIFFSTORE`, `SINTERSTORE` and `SUNIONSTORE` to
perform the underlying operations, and it takes care of generating
and deleting any temporary keys.

Note that the only valid names for the internal commands are
`:SUNION`, `:SDIFF` and `:SINTER`. Any other internal command will
raise an error. The outmost command can be any set operation, for
example:

```elixir
expr = [:SCARD, [:SINTER, "foo", "bar"]]

Stal.solve(redis, expr)
#=> {:ok, 2}
```

If you want to preview the commands `Stal` will send to generate
the results, you can use `Stal.explain`:

```elixir
Stal.explain([:SINTER, [:SUNION, "foo", "bar"], "baz"])
#  [["SUNIONSTORE", "stal:0", "foo", "bar"],
#   [:SINTER, "baz", "stal:0"]]
```

All commands are pipelined and wrapped in a `MULTI/EXEC` transaction.

Installation
------------

```elixir
  1. Add stal to your list of dependencies in `mix.exs`:

        def deps do
          [{:stal,"~> 0.0.1", github: "lastcanal/elixir-stal"}]
        end

  2. Ensure stal is started before your application:

        def application do
          [applications: [:stal]]
        end
```

[redis]: http://redis.io
[stal]: https://github.com/soveran/stal
[redix]: https://github.com/whatyouhide/redix
[eredis]: https://github.com/wooga/eredis


