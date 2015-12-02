defmodule Stal do

  defstruct id: nil, item: [], ids: [], ops: [],
            module: Redix, method: :command

  defmodule InvalidCommand do
    defexception message: "invalid command"
  end

  def command(:SDIFF), do: "SDIFFSTORE"
  def command(:SINTER), do: "SINTERSTORE"
  def command(:SUNION), do: "SUNIONSTORE"
  def command(command), do:
    raise InvalidCommand, message: command

  def compile(expr, state) do
    Enum.reduce(expr, state, &compile_item(&1, &2))
  end

  defp compile_item(item, %Stal{ids: []} = state) when is_list(item) do
    convert(item, state)
  end
  defp compile_item(item, %Stal{item: item0} = state) when is_list(item) do
    %Stal{id: id} = state = convert(item, state)
    %Stal{state | item: item0 ++ [id]}
  end
  defp compile_item(item, %Stal{item: item0} = state) do
    %Stal{state | item: item0 ++ [item]}
  end

  def convert([head|tail], %Stal{item: item0, ids: ids, ops: ops} = state) do
    id = "stal:#{length(ids)}"
    ids = [id|ids]
    op = [command(head), id]

    %Stal{item: item, ids: ids, ops: ops} =
      compile(tail, %Stal{state | item: [], ids: ids, ops: ops})

    op = op ++ item
    ops = ops ++ [op]

    %Stal{state | id: id, item: item0, ids: ids, ops: ops}
  end

  def explain(expr) do
    %Stal{ops: ops} = explain(expr, %Stal{})
    ops
  end

  def explain(expr, state) do
    %Stal{id: id, item: item, ops: ops} = state = compile(expr, state)
    item = if id, do: item ++ [id], else: item
    %Stal{state | ops:  ops ++ [item], item: []}
  end

  def solve(c, %Stal{ops: [op], module: mod, method: method}), do: apply(mod, method, [c, op])
  def solve(c, %Stal{ids: ids, ops: ops, module: mod, method: method}) do
    {:ok, "OK"} = apply(mod, method, [c, ["MULTI"]])
    Enum.each ops, fn(command) ->
      {:ok, "QUEUED"} = apply(mod, method, [c, command])
    end
    {:ok, "QUEUED"} = apply(mod, method, [c, ["DEL"] ++ ids])
    {:ok, reply} = apply(mod, method, [c, ["EXEC"]])
    [_,result|_] = Enum.reverse(reply)
    {:ok, result}
  end

  def solve(c, expr, state \\ %Stal{}) do
    state = explain(expr, state)
    solve(c, state)
  end


end
