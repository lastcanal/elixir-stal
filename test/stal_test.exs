defmodule StalTest do
  use ExUnit.Case
  doctest Stal

  setup do
    Redix.command :r, ["FLUSHDB"]
    Redix.command :r, ["SADD", "foo", "a", "b", "c"]
    Redix.command :r, ["SADD", "bar", "b", "c", "d"]
    Redix.command :r, ["SADD", "baz", "c", "d", "e"]
    Redix.command :r, ["SADD", "qux", "x", "y", "z"]
    :ok
  end

  test "all" do
    expr = ["SUNION", "qux", [:SDIFF, [:SINTER, "foo", "bar"], "baz"]]

    assert ["b", "x", "y", "z"] == Stal.solve(:r, expr) |> elem(1) |> Enum.sort

    # Commands in sub expressions must be symbols
    expr = ["SUNION", "qux", ["SDIFF", ["SINTER", "foo", "bar"], "baz"]]

    assert_raise Stal.InvalidCommand, fn ->
      Stal.solve(:r, expr)
    end

    # Commands without sub expressions also work
    expr = ["SINTER", "foo", "bar"]

    assert ["b", "c"] == Stal.solve(:r, expr) |> elem(1) |> Enum.sort

    # Only :SUNION, :SDIFF and :SINTER are supported in sub expressions
    expr = ["SUNION", ["DEL", "foo"]]

    assert_raise Stal.InvalidCommand, "DEL", fn ->
       Stal.solve(:e, expr)
     end

    # Verify there's no keyspace pollution
    assert ["bar", "baz", "foo", "qux"] == Redix.command(:r, ["KEYS", "*"]) |> elem(1) |> Enum.sort

    expr = ["SCARD", [:SINTER, "foo", "bar"]]

    # Explain returns an array of Redis commands
    expected = [["SINTERSTORE", "stal:0", "foo", "bar"], ["SCARD", "stal:0"]]

    assert expected == Stal.explain(expr)
  end

  defmodule FakeRedis do
    def execute(_c, _expr) do
      {:ok, ["a","b"]}
    end
  end

  test "alternate client" do
    state = %Stal{module: StalTest.FakeRedis, function: :execute}
    assert ["a", "b"] == Stal.solve(:r, [], state) |> elem(1) |> Enum.sort
  end
end
