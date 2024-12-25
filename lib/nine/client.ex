defmodule Ex9P.Nine.Client do
  use GenServer

  alias Ex9P.Conn

  def start_link(opts) do
    {server_opts, opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, opts, server_opts)
  end

  @impl true
  def init(opts) do
    opts = Keyword.validate!(opts, [:address, :port, :connect_opts, :conn])

    conn =
      with nil <- opts.conn do
        {:ok, conn} = Conn.connect(opts.address, opts.port, opts.connect_opts)
        conn
      end

    state = %{
      conn: conn
    }

    {:ok, state}
  end
end
