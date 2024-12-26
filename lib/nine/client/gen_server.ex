defmodule Ex9P.Nine.Client.GenServer do
  use GenServer

  alias Ex9P.Conn
  alias Ex9P.Nine

  @version "9P2000"

  def start_link(opts) do
    {server_opts, opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, opts, server_opts)
  end

  @impl true
  def init(opts) do
    opts = Keyword.validate!(opts, [:address, port: 0, connect_opts: [], msize: 8192])
    {:ok, conn} = Conn.connect(opts[:address], opts[:port], opts[:connect_opts])

    state = %{
      conn: conn,
      tags: %{},
      msize: [],
      next_tag: 1,
      next_fid: 1
    }

    :ok = Conn.send(state.conn, %Nine.Tversion{msize: opts[:msize], version: @version})
    {:ok, state}
  end

  @impl true
  def handle_call({:request, msg}, from, state) do
    if is_integer(state.msize) do
      state = request(state, msg, from)
      {:noreply, state}
    else
      state = update_in(state.msize, &[{msg, from} | &1])
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:next_fid, _from, state) do
    {fid, state} = get_and_update_in(state.next_fid, &{&1, &1 + 1})
    {:reply, fid, state}
  end

  @impl true
  def handle_call(:msize, from, state) do
    case state.msize do
      msize when is_integer(msize) ->
        {:reply, msize, state}

      msize when is_list(msize) ->
        state = %{state | msize: [{:msize, from} | msize]}
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({Ex9P, conn, {tag, msg}}, %{conn: conn} = state) do
    {from, state} = pop_in(state.tags[tag])
    GenServer.reply(from, msg)

    {:noreply, state}
  end

  @impl true
  def handle_info({Ex9P, conn, %Nine.Rversion{msize: msize}}, %{conn: conn, msize: queue} = state) do
    state = %{state | msize: msize, tags: %{}}
    state = empty_queue(state, queue)
    {:noreply, state}
  end

  defp request(state, msg, from) do
    {tag, state} = get_and_update_in(state.next_tag, &{&1, &1 + 1})
    state = put_in(state.tags[tag], from)

    :ok = Conn.send(state.conn, {tag, msg})
    state
  end

  defp empty_queue(state, queue) when is_list(queue) do
    queue
    |> Enum.reverse()
    |> Enum.reduce(state, fn
      {:msize, from}, state ->
        GenServer.reply(from, state.msize)
        state

      {msg, from}, state ->
        request(state, msg, from)
    end)
  end

  defp empty_queue(state, queue) when is_integer(queue) do
    state
  end
end
