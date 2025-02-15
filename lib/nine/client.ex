defmodule Ex9P.Nine.Client do
  alias Ex9P.Nine
  alias Ex9P.Nine.DirEntry

  @opaque t() :: GenServer.server()

  defmodule File do
    use TypedStruct

    typedstruct enforce: true do
      field :client, Nine.Client.t()
      field :fid, Nine.fid()
      field :qid, Nine.QID.t()
    end
  end

  @doc false
  defdelegate child_spec(spec), to: __MODULE__.GenServer

  defdelegate start_link(opts), to: __MODULE__.GenServer

  defp request(client, msg) do
    GenServer.call(client, {:request, msg})
  end

  @spec msize(t()) :: pos_integer()
  def msize(client) do
    GenServer.call(client, :msize)
  end

  @spec attach(t(), String.t(), String.t(), File.t() | nil) ::
          {:ok, File.t()} | {:error, Exception.t()}
  def attach(client, aname, uname, afile \\ nil) do
    afid = if afile, do: afile.fid, else: :nofid
    fid = GenServer.call(client, :next_fid)
    rsp = request(client, %Nine.Tattach{uname: uname, aname: aname, fid: fid, afid: afid})

    with %Nine.Rattach{qid: qid} <- rsp do
      {:ok, %File{client: client, fid: fid, qid: qid}}
    else
      err when is_exception(err) -> {:error, err}
    end
  end

  @spec stat(File.t()) :: {:ok, DirEntry.t()} | {:error, String.t()}
  def stat(%File{client: client, fid: fid}) do
    rsp = request(client, %Nine.Tstat{fid: fid})

    with %Nine.Rstat{stat: stat} <- rsp do
      {:ok, stat}
    else
      err when is_exception(err) -> {:error, err}
    end
  end

  @spec walk(File.t(), String.t()) :: {:ok, File.t()} | {:error, String.t()}
  def walk(%File{client: client, fid: fid}, path) when is_binary(path) do
    wname = String.split(path, "/", trim: true)
    newfid = GenServer.call(client, :next_fid)
    rsp = request(client, %Nine.Twalk{fid: fid, newfid: newfid, wname: wname})

    with %Nine.Rwalk{wqid: wqid} <- rsp do
      {:ok, %File{client: client, fid: newfid, qid: List.last(wqid)}}
    else
      err when is_exception(err) -> {:error, err}
    end
  end

  @spec open(File.t(), [Nine.mode()]) :: :ok | {:error, Exception.t()}
  def open(%File{client: client, fid: fid}, mode \\ [:read]) do
    rsp = request(client, %Nine.Topen{fid: fid, mode: mode})

    with %Nine.Ropen{} <- rsp do
      :ok
    else
      err when is_exception(err) -> {:error, err}
    end
  end

  @spec clunk(File.t()) :: :ok | {:error, Exception.t()}
  def clunk(%File{client: client, fid: fid}) do
    rsp = request(client, %Nine.Tclunk{fid: fid})

    with %Nine.Rclunk{} <- rsp do
      :ok
    else
      err when is_exception(err) -> {:error, err}
    end
  end

  @spec read(File.t(), non_neg_integer(), non_neg_integer() | :msize) ::
          {:ok, iodata()} | {:error, Exception.t()}
  def read(%File{client: client, fid: fid}, offset, count \\ :msize) when is_integer(offset) do
    count = normalize_chunk_size(count, client)
    rsp = request(client, %Nine.Tread{fid: fid, offset: offset, count: count})

    with %Nine.Rread{data: data} <- rsp do
      {:ok, data}
    else
      err when is_exception(err) -> {:error, err}
    end
  end

  @spec write(File.t(), non_neg_integer(), iodata()) ::
          {:ok, count} | {:error | Exception.t()}
        when count: non_neg_integer()
  def write(%File{client: client, fid: fid}, offset, data) when is_integer(offset) do
    rsp = request(client, %Nine.Twrite{fid: fid, offset: offset, data: data})

    with %Nine.Rwrite{count: count} <- rsp do
      {:ok, count}
    else
      err when is_exception(err) -> {:error, err}
    end
  end

  @spec stream(File.t(), keyword()) :: Enumerable.t(iodata())
  def stream(%File{client: client} = file, opts \\ []) do
    opts = Keyword.validate!(opts, starting_offset: 0, chunk_size: :msize)
    chunk_size = normalize_chunk_size(opts[:chunk_size], client)

    %Nine.Stream{
      file: file,
      offset: opts[:starting_offset],
      count: chunk_size
    }
  end

  @spec readdir(iodata()) :: Enumerable.t(Nine.DirEntry.t())
  def readdir(data) do
    data
    |> IO.iodata_to_binary()
    |> Stream.unfold(fn
      "" -> nil
      data -> Nine.DirEntry.decode(data)
    end)
  end

  defp normalize_chunk_size(:msize, client) do
    msize(client) - (Ex9P.Proto.header_size() + 17)
  end

  defp normalize_chunk_size(chunk_size, _client) do
    chunk_size
  end
end
