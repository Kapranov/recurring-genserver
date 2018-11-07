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

### 7 November 2018 by Oleg G.Kapranov
