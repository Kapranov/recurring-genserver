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

### 7 November 2018 by Oleg G.Kapranov
