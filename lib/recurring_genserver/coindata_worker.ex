defmodule RecurringGenserver.CoindataWorker do
  @moduledoc false

  use GenServer

  alias RecurringGenserver.Coindata

  @doc false
  def start_link(opts) do
    id = Map.get(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: id)
  end

  @doc false
  def init(state) do
    schedule_coin_fetch()
    {:ok, state}
  end

  @doc false
  def handle_info(:coin_fetch, state) do
    updated_state = state
      |> Map.get(:id)
      |> Coindata.fetch()
      |> update_state(state)

    if updated_state[:price] != state[:price] do
      # credo:disable-for-next-line
      IO.inspect("Current #{updated_state[:name]} price is $#{updated_state[:price]}")
    end

    schedule_coin_fetch()
    {:noreply, updated_state}
  end

  @doc false
  defp update_state(%{"display_name" => name, "price" => price}, existing_state) do
    Map.merge(existing_state, %{name: name, price: price})
  end

  @doc false
  defp schedule_coin_fetch do
    Process.send_after(self(), :coin_fetch, 5_000)
  end
end
