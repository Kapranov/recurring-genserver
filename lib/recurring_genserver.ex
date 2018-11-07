defmodule RecurringGenserver do
  @moduledoc false

  use Application

  @doc false
  def start(_type, _args) do
    RecurringGenserver.Supervisor.start_link(
      name: RecurringGenserver.Supervisor
    )
  end
end
