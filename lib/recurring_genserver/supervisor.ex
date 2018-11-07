defmodule RecurringGenserver.Supervisor do
  @moduledoc false

  use Supervisor

  @doc false
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @doc false
  def init(:ok) do
    children = get_children()

    opts = [strategy: :one_for_one, name: RecurringGenserver.Supervisor]

    Supervisor.init(children, opts)
  end

  @doc false
  defp get_children do
    Enum.map([:btc, :eth, :ltc], fn(coin) ->
      Supervisor.child_spec({RecurringGenserver.CoindataWorker, %{id: coin}}, id: coin)
    end)
  end
end
