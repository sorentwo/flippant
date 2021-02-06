# Flippant

[![Build Status](https://travis-ci.org/sorentwo/flippant.svg?branch=master)](https://travis-ci.org/sorentwo/flippant)
[![Coverage Status](https://coveralls.io/repos/github/sorentwo/flippant/badge.svg?branch=master)](https://coveralls.io/github/sorentwo/flippant?branch=master)
[![Hex version](https://img.shields.io/hexpm/v/flippant.svg "Hex version")](https://hex.pm/packages/flippant)
[![Inline docs](https://inch-ci.org/github/sorentwo/flippant.svg)](https://inch-ci.org/github/sorentwo/flippant)

> Flippant is a library for feature toggling in Elixir applications

## Installation

1. Add `flippant` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:flippant, "~> 2.0"}]
  end
  ```

2. Add an adapter such as `redix` for Redis or `postgrex` for Postgres:

  ```elixir
  def deps do
    [{:redix, "~> 1.0"}]
  end
  ```

3. Set an adapter within your `config.exs`:

  ```elixir
  config :flippant,
         adapter: Flippant.Adapter.Redis,
         redis_opts: [url: System.get_env("REDIS_URL"), name: :flippant],
         set_key: "flippant-features"
  ```

## Usage

Complete [documentation is available online](https://hexdocs.pm/flippant), but
here is a brief overview:

Features are comprised of `groups`, and `rules`. Your application defines named
`groups`, and you set `rules` to specify which `groups` are enabled for a
particular feature. When it comes time to check if a feature is enabled for a
particular `actor` (i.e. user or account), all the `groups` for a feature are
evaluated. If the `actor` belongs to any of the `groups` then the feature is
enabled.

All interaction happens directly through the `Flippant` module.

Define some basic groups:

```elixir
Flippant.register("staff", fn %User{staff?: staff?}, _ -> staff?)
Flippant.register("testers", fn %User{id: id}, ids -> id in ids end)
```

Set a few rules for the "search" feature:

```elixir
Flippant.enable("search", "staff")
Flippant.enable("search", "testers", [1818, 1819])
```

Check if the current user has access to a feature:

```elixir
Flippant.enabled?("search", %User{id: 1817, staff?: false}) #=> true
Flippant.enabled?("search", %User{id: 1818, staff?: false}) #=> false
Flippant.enabled?("search", %User{id: 1820, staff?: true}) #=> true
```

## License

MIT License, see [LICENSE.txt](LICENSE.txt) for details.
