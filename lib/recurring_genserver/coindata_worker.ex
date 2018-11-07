defmodule RecurringGenserver.CoindataWorker do
  @moduledoc false

  use GenServer

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  def init(state) do
    schedule_coin_fetch()
    {:ok, state}
  end

  @doc false
  def handle_info(:coin_fetch, state) do
    price = coin_price()
    IO.puts("Current Bitcoin price is $#{price}")
    schedule_coin_fetch()
    {:noreply, Map.put(state, :btc, price)}
  end

  @doc false
  defp coin_price do
    "http://coincap.io/page/BTC"
    |> HTTPoison.get!()
    |> Map.get(:body)
    |> Jason.decode!()
    |> Map.get("price_usd")
  end

  @doc false
  defp schedule_coin_fetch do
    Process.send_after(self(), :coin_fetch, 5_000)
  end
end
