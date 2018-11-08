#58: Recurring Work with GenServer

Generally if you needed to do some kind of recurring work you’d maybe
use something like a cron or maybe even  a separate  library. In this
example application  we're going to see how  we can use  GenServer to
schedule  some  recurring work. We'll create a GenServer process that
fetches the current price of Bitcoin at a regular interval.

The first thing we'll need to do is create a new Elixir project. Let's
call our's `recurring-genserver` and we won't pass the `--sup` option
to create an OTP application skeleton with a supervision tree. We'll
create it a later customer module for that:

```bash
mkdir recurring-genserver; cd recurring-genserver

mix new . --app recurring_genserver
```

Then let's change into our new directory and open our project and
install packages for static code analysis tool and test notifier.

```elixir
# mix.exs
defmodule RecurringGenserver.MixProject do
  use Mix.Project

  def project do
    [
      app: :recurring_genserver,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: applications(Mix.env)
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10.1", only: :test},
      {:ex_unit_notifier, "~> 0.1.4", only: :test},
      {:httpoison, "~> 1.4.0"},
      {:jason, "~> 1.1.2"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:remix, "~> 0.0.2", only: :dev}
    ]
  end

  defp applications(:dev), do: applications(:all) ++ [:remix]
  defp applications(_all), do: [:logger]
end
```

```elixir
# config/config.exs
use Mix.Config

if Mix.env == :dev do
  config :mix_test_watch, clear: true
  config :remix, escript: true, silent: true
end

if Mix.env == :test do
  config :ex_unit_notifier,
    notifier: ExUnitNotifier.Notifiers.NotifySend
end

# import_config "#{Mix.env()}.exs"
```

```elixir
# test/recurring_genserver_test.exs
ExUnit.configure formatters: [ExUnit.CLIFormatter, ExUnitNotifier]
ExUnit.start()
```

```bash
# Makefile
V ?= @
SHELL := /usr/bin/env bash
ERLSERVICE := $(shell pgrep beam.smp)

ELIXIR = elixir

VERSION = $(shell git describe --tags --abbrev=0 | sed 's/^v//')

NO_COLOR=\033[0m
INFO_COLOR=\033[2;32m
STAT_COLOR=\033[2;33m

# ------------------------------------------------------------------------------

help:
			$(V)echo Please use \'make help\' or \'make ..any_parameters..\'

push:
			$(V)git add .
			$(V)git commit -m "added support Makefile"
			$(V)git push -u origin master

git-%:
			$(V)git pull

kill:
			$(V)echo "Checking to see if Erlang process exists:"
			$(V)if [ "$(ERLSERVICE)" ]; then killall beam.smp && echo "Running Erlang Service Killed"; else echo "No Running Erlang Service!"; fi

clean:
			$(V)mix deps.clean --all
			$(V)mix do clean
			$(V)rm -fr _build/ ./deps/

packs:
			$(V)mix deps.get
			$(V)mix deps.update --all
			$(V)mix deps.get

report:
			$(V)MIX_ENV=dev
			$(V)mix coveralls
			$(V)mix coveralls.detail
			$(V)mix coveralls.html
			$(V)mix coveralls.json

test:
			$(V)clear
			$(V)echo -en "\n\t$(INFO_COLOR)Run server tests:$(NO_COLOR)\n\n"
			$(V)mix test

credo:
			$(V)mix credo --strict
			$(V)mix coveralls

run: kill clean packs
			$(V)iex -S mix

halt: kill
			$(V)echo -en "\n\t$(STAT_COLOR) Run server http://localhost:$(NO_COLOR)$(INFO_COLOR)PORT$(NO_COLOR)\n"
			$(V)mix run --no-halt

start: kill
			$(V)echo -en "\n\t$(STAT_COLOR) Run server http://localhost:$(NO_COLOR)$(INFO_COLOR)PORT$(NO_COLOR)\n"
			$(V)iex -S mix

all: test credo report start

.PHONY: test halt
```

```bash
# run.sh
#!/usr/bin/env bash

make start
```

Since our project will be fetching the price of a Bitcoin, we need a
place to fetch Bitcoin data.

Let's use the free API provided by CoinCap. We can use the `/page`
endpoint to get data about a specific coin.

Alright, now that we know where we'll want to fetch our data from, we
just need a way to fetch the data. Let's bring in two packages to help
us. We'll use the "HTTPoison" library to get the price data from
CoinCap. Let's copy the package.

The we'll go back to our project and open the Mixfile and add
`httpoison` to our list of dependencies. We'll also add the
`jason`package to help us parse the JSON that’s returned.

Let's create for supervisor tree a file 'supervisor.ex'

```bash
mkdir lib/recurring_genserver/
touch lib/recurring_genserver/supervisor.ex
```

```elixir
# mix.exs
defmodule RecurringGenserver.MixProject do
  use Mix.Project

  # ...

  def application do
    [
      extra_applications: applications(Mix.env),
      mod: {RecurringGenserver, []}
    ]
  end

  # ...

end

# lib/recurring_genserver.ex
defmodule RecurringGenserver do
  @moduledoc false

  use Application

  def start(_type, _args) do
    RecurringGenserver.Supervisor.start_link(
      name: RecurringGenserver.Supervisor
    )
  end
end

# lib/recurring_genserver/supervisor.ex
defmodule RecurringGenserver.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

Then let's go to the command line and download our dependencies.
`make all` and then `:observer.start`

```bash
iex> Process.whereis RecurringGenserver.Supervisor  #=> #PID<0.211.0>
iex> Process.alive? pid(0,211,0)                    #=> true
iex> Process.info(pid(0,211,0))
```

Great, now let's see how we can fetch the price of a Bitcoin.

Let's start `make all` with our project. The let's get the pricing data.
We'll call `HTTPoison.get!` passing in the URL we want to want to get
data from. We'll use the `/page` endpoint to get data about a specific
cryptocurrency and we'll give it the ID of the coin we want to get - in
this case BTC for Bitcoin.

Great, we were able to get the data. Let's take our response body and
pass it into `Jason.decode!`. And great, we see that the data was parsed
and we can see the information that's provided, like the name of the
coin, the market cap, and the current price. This is exactly the data we
want.

```bash
bash> make all

iex> response = HTTPoison.get!("http://coincap.io/page/BTC")
#=> %HTTPoison.Response{
      body: "{\"altCap\":107690074031.78757,
              \"bitnodesCount\":10049,
              \"btcCap\":113642702993.96036,
              \"btcPrice\":6549.995,
              \"dom\":47.27,\"totalCap\":221332777025.74805,
              \"volumeAlt\":366910908.0875777,
              \"volumeBtc\":328977581.10892534,
              \"volumeTotal\":695888489.196504,
              \"id\":\"BTC\",
              \"type\":\"cmc\",
              \"_id\":\"179bd7dc-72b3-4eee-b373-e719a9489ed9\",
              \"price_btc\":1,
              \"price_eth\":29.58510461554865,
              \"price_ltc\":118.56576020838553,
              \"price_zec\":50.17738313656813,
              \"price_eur\":5685.197231839393,
              \"price_usd\":6549.995,
              \"market_cap\":113642702993.96036,
              \"cap24hrChange\":1.71,
              \"display_name\":\"Bitcoin\",
              \"status\":\"available\",
              \"supply\":17364012,
              \"volume\":5200564411.33,
              \"price\":6544.72612631,
              \"vwap_h24\":6532.808978059005,
              \"rank\":1,
              \"alt_name\":\"bitcoin\"}",
      headers: [
        {"Date", "Wed, 07 Nov 2018 09:54:16 GMT"},
        {"Content-Type", "application/json; charset=utf-8"},
        {"Content-Length", "679"},
        {"Connection", "keep-alive"},
        {"Set-Cookie",
          "__cfduid=d52237651f0334bf03eb7cdfd2903de1a1541584456; expires=Thu,
          07-Nov-19 09:54:16 GMT;path=/; domain=.coincap.io; HttpOnly"},
        {"x-powered-by", "Express"},
        {"access-control-allow-origin", "*"},
        {"x-content-type-options", "nosniff"},
        {"etag", "W/\"2a7-NehEeDKpOQx6+RFsla4sdNTdQTk\""},
        {"apicache-store", "memory"},
        {"apicache-version", "0.8.7"},
        {"Cache-Control", "s-maxage=60, max-age=60"},
        {"X-Cache-Status", "EXPIRED"},
        {"CF-Cache-Status", "HIT"},
        {"Server", "cloudflare"},
        {"CF-RAY", "475eeae264478af2-KBP"}
      ],
      request: %HTTPoison.Request{
        body: "",
        headers: [],
        method: :get,
        options: [],
        params: %{},
        url: "http://coincap.io/page/BTC"
      },
      request_url: "http://coincap.io/page/BTC",
      status_code: 200
    }

iex> response.body |> Jason.decode!()
#=> %{
      "_id" => "179bd7dc-72b3-4eee-b373-e719a9489ed9",
      "altCap" => 107690074031.78757,
      "alt_name" => "bitcoin",
      "bitnodesCount" => 10049,
      "btcCap" => 113642702993.96036,
      "btcPrice" => 6549.995,
      "cap24hrChange" => 1.71,
      "display_name" => "Bitcoin",
      "dom" => 47.27,
      "id" => "BTC",
      "market_cap" => 113642702993.96036,
      "price" => 6544.72612631,
      "price_btc" => 1,
      "price_eth" => 29.58510461554865,
      "price_eur" => 5685.197231839393,
      "price_ltc" => 118.56576020838553,
      "price_usd" => 6549.995,
      "price_zec" => 50.17738313656813,
      "rank" => 1,
      "status" => "available",
      "supply" => 17364012,
      "totalCap" => 221332777025.74805,
      "type" => "cmc",
      "volume" => 5200564411.33,
      "volumeAlt" => 366910908.0875777,
      "volumeBtc" => 328977581.10892534,
      "volumeTotal" => 695888489.196504,
      "vwap_h24" => 6532.808978059005
    }
```

Then if we go into our `lib` directory, we see a module named
`recurring_genserver`. Let's open it.

When our Elixir application is started, our `start` callback is called,
which starts our supervision tree. You can read more about applications
in Elixir here in the Elixir docs, which I've linked to here:
[https://hexdocs.pm/elixir/Application.html][Application]

But for our project all you really need to remember is that if a worker
module is included here in our `children` it will be started
automatically as part of our supervision tree and will be supervised
according to the options specified here: `strategy: one_for_one`

What this means is that if something happens while we’re trying to fetch
our data and our child process is terminated, only that process will be
restarted. Alright, now let's create a module to do some work. Let's
create a new module in the same directory named `coindata_worker.ex`.
The we'll define our module.

And we'll make this module a `GenServer`. If you're new to `GenServer`'s
and want to learn more, check out episode #12 where we get an
introduction to them. Our `GenServer` will schedule recurring work by
sending a message to itself in a specified interval.

First off let's implement the `start_link` function we'll use the
current module and pass down any arguments. And let's make this a named
GenServer, using the current module for the name, Then we'll implement
the `init` callback. We'll need to return an OK tuple with our state.

Now when our GenServer is started, let’s schedule the first fetch of our
coin data. We'll do that here, so let's call a new a function we'll need
to implement called `schedule_coin_fetch`, then let's implement it as a
private function.

Inside the function we’ll call `Process.send_after`. This allows us to
send a message to a process after a certain interval. Let's use `self`
for the destination process, we'll call our message `:coin_fetch`, and
let's schedule it to happen in 5 seconds. We'll use 5 seconds here so we
have some nice feedback when we run it. Normally we wouldn't want to
this to be as frequent since prices are only updated every minute of so.

Now we need to implement a `handle_info` callback to handle this
message. We'll pattern match on the `:coin_fetch` atom and accept the
current state of the GenServer.

Now let's fetch our coin data. We'll take the URL we'll use to get our
data and pipe it into `HTTPoison.get!` and then into `Map.get` to get
the response body, then we'll decode it with `Jason.decode!`.

Finally let's get the price with `Map.get`, now that we have the price
let's print what the price was.

Then we'll need to return an ‘noreply’ tuple and let's update the state
of our GenServer to hold the current price of a Bitcoin. This will be
triggered when our GenServer is started and the price will be logged.
Now if we want this to keep running and print our message again in
another 5 seconds, we'll need to make another call to our
`schedule_coin_fetch` function. So let's add that.

And let's clean our function up a bit and move the logic that fetches
our coin price into it's own function we'll call `coin_price`.

```bash
bash> touch lib/recurring_genserver/coindata_worker.ex
bash> touch lib/recurring_genserver/coindata.ex
```

```elixir
# lib/recurring_genserver/coindata_worker.ex
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
```

```elixir
defmodule RecurringGenserver.Coindata do
  @moduledoc false
end
```

Now that our module is finished, let's add it to our supervisor. We'll
go back to our `supervisor.ex` module. And let's include our new module
in our children list. For the initial state we'll use an empty map.

```elixir
# lib/recurring_genserver/supervisor.ex
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
```

Now let's go to the command line and run `make all` with our project. And we
see the price of a Bitcoin is being logged.

Let's also start our `:observer.start`. And if we click on the "applications"
tab we see our supervisor and it has a single child process - our
`CoindataWorker`.

We see it's named this in the observer since we added the module for the
name earlier. And if we go to it and then click the "state" tab we see
the state of our GenServer has the current price of a Bitcoin.

```bash
bash> make all

iex> Current Bitcoin price is $6549.995
     Current Bitcoin price is $6549.995
     Current Bitcoin price is $6549.995
     Current Bitcoin price is $6549.995
     Current Bitcoin price is $6549.995
     ...
```

This is great - we're fetching data from the API, parsing it, and
logging the price. Then our GenServer is scheduling itself to fetch the
price again in the future.

This is pretty cool. But now let's say we wanted to get the prices of
other cryptocurrencies - not just Bitcoin. How can we update our program
to do that?

Let's go our `coindata_worker.ex` module. There are a couple different
ways we could do this. We could store the price for any cryptocurrency
we wanted to track in this single GenServer process. However let's
create a CoinDataWorker process for each cryptocurrency we want to
track.

To differentiate what coin we want to track, let's pass the ID of the
coin in the arguments. So for bitcoin it will be `:btc` as a lowercase
atom.

Our args will be a map, so let's grab the ID from them. And because we
can't start multiple GenServers with the same name, let's use the ID for
the name.

Since we want to make the lookup for the coin we are getting data for
dynamic, let's go to our `handle_info` callback. And we've hardcoded
this to be about Bitcoin, so let's fix that.

First since we'll have access to the coin's ID in our state, let's get
that. We'll take our state and pipe it into `Map.get` :id to get the id.

Then let's pipe it into our `coin_price` function. But we'll now want
this to return more data than just the price. In fact let's rename it to
`coindata` and have it return all the coin data we get back from the API.
Then we'll go where we've defined our `coin_price` function, rename it,
and update it to take the ID.

Since the ID will be a lowercase atom, we'll need to convert to an
uppercase string to use in the URL. So let's take our ID and pipe it
into `Atom.to_string` then we'll pipe our string into `String.upcase`

Now that we'll have our coin ID we can use it in our URL. Let's create
another function we'll add to our pipeline to build our URL. Let's call
it `url`.

We'll define our new function `url` and it will take the ID. Then in the
function we'll update our URL and append the ID to it. Then back in our
`coindata` function we'll get the response body and decode the JSON just
like before, only now let's return the whole data map.

Alright, now that we are returning all our data, let's create a way to
merge our existing state with the data we care about. Let's add a new
function to our pipeline called `update_state` that we'll need to
implement. It will take our new data and our existing state.

Then let's define it as a private function and let's pattern match on
our new data to get the name of the coin and the price.

Then inside the function we'll call `Map.merge` to update our existing
state with our new values. Great then back in our `handle_info` callback.
We're no longer returning a price, so let's change the variable name to
`updated_state`, and let's update our message.

Now this will log the current price of a cryptocurrency regardless of
whether the price has changed or not. This is pretty noisy and will be
even worse now that we want to track more coins. So let's update this
to only print if our new price is different than our existing price.
Finally let’s return our `updated_state`.

```elixir
# lib/recurring_genserver/coindata_worker.ex
defmodule RecurringGenserver.CoindataWorker do
  @moduledoc false

  use GenServer

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
      |> coin_data()
      |> update_state(state)

    if updated_state[:price] != state[:price] do
      # credo:disable-for-next-line
      IO.inspect("Current #{updated_state[:name]} price is $#{updated_state[:price]}")
    end

    {:noreply, updated_state}
  end

  @doc false
  defp coin_data(id) do
    id
    |> Atom.to_string()
    |> String.upcase()
    |> url()
    |> HTTPoison.get!()
    |> Map.get(:body)
    |> Jason.decode!()
  end

  @doc false
  defp url(id) do
    "http://coincap.io/page/" <> id
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
```

Great, now this will work, but let's break up our module a bit. Let's
move the logic that fetches the coin data into its own module.

We'll create a new module named `coindata.ex`, then let's give it a
public function named fetch and back in our `coindata_worker.ex` let's
copy our two functions that fetch the coin data - `url` and `coindata`.
Then let's paste them into the `coindata.ex` module. And we'll move our
pipeline from the `coindata` function into the `fetch` function and
update it to take an ID.

```elixir
# lib/recurring_genserver/coindata.ex
defmodule RecurringGenserver.Coindata do
  @moduledoc false

  @doc false
  def fetch(id) do
    id
    |> Atom.to_string()
    |> String.upcase()
    |> url()
    |> HTTPoison.get!()
    |> Map.get(:body)
    |> Jason.decode!()
  end

  defp url(id) do
    "http://coincap.io/page/" <> id
  end
end
```

Then we'll go back to our `coindata_worker.ex` module and where we were
calling the `coindata` function, we'll now call `Coindata.fetch` and
let's add an alias for it so we can call it without the prefix.

```elixir
# lib/recurring_genserver/coindata_worker.ex
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
```

Now let's go to our `supervisor.ex` module. And let's keep this simple
and just add a new private function named `get_children`. Then we'll
call `Enum.map` with a list of the coin IDs we want to track - Bitcoin,
Ethereum , and Litecoin.

Let's return our `RecurringGenserver.CoindataWorker` and we'll need to
include a map that has the coin ID so our module can use it. Then let's
update our `start` callback to use our new function.

```elixir
# lib/recurring_genserver/supervisor.ex
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
      {RecurringGenserver.CoindataWorker, %{id: coin}}
    end)
  end
end
```

Then let's go to the command line and start `make all` with our project -
and we get an error. Elixir is telling up that multiple child specifications
are using the same ID.

But if we read farther down, Elixir tells us that we can customize the
ID with the `Supervisor.child_spec`  function, giving it a unique ID. So
let's do that.

```bash
** (Mix) Could not start application recurring_genserver:
RecurringGenserver.start(:normal, []) returned an error:
If using maps as child specifications, make sure the :id keys are unique.
If using a module or {module, arg} as child, use Supervisor.child_spec/2
to change the :id, for example:

    children = [
      Supervisor.child_spec({MyWorker, arg}, id: :my_worker_1),
      Supervisor.child_spec({MyWorker, arg}, id: :my_worker_2)
    ]
```

We'll go back to our `supervisor.ex` module and update our `get_children`
function to use `Supervisor.child_spec` and we'll use the coin ID for the
ID.

```elixir
# lib/recurring_genserver/supervisor.ex
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
```

Now we can start our project again. And perfect, the prices for our
three coins are printed.

```bash
bash> make all

iex> "Current Bitcoin  price is $6540.25807609"
     "Current Ethereum price is $217.821259803"
     "Current Litecoin price is $54.2257445259"

iex> :observer.start
```

And let's start the observer. Because we are using the coin ID for the
GenServer name, we see all three of our processes have the coin ID for
their name. Let's choose one. And click the "state" tab.

Perfect, we see all the information is stored. Our program is working
and printing the price for us when it change.

### 7 November 2018 by Oleg G.Kapranov

[1]: https://elixircasts.io/recurring-work-with-genserver
[2]: https://github.com/elixircastsio/058-recurring-work-genserver
