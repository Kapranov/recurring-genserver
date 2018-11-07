defmodule RecurringGenserverTest do
  use ExUnit.Case
  doctest RecurringGenserver

  test "greets the world" do
    assert RecurringGenserver.hello() == :world
  end
end
