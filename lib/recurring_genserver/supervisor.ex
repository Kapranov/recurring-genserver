defmodule RecurringGenserver.Supervisor do
  @moduledoc false

  use Supervisor

  @doc false
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @doc false
  def init(:ok) do
    children = [
      {RecurringGenserver.CoindataWorker, %{}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
