# Flippant

Fast feature toggling for Elixir applications, backed by Redis.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add flippant and redix to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:flippant, "~> 0.1"},
       {:redix, "~> 0.4"}]
    end
    ```

  2. Ensure flippant and redix is started before your application:

    ```elixir
    def application do
      [applications: [:redix, :flippant]]
    end
    ```

  3. Set an adapter within your `config.exs`:

    ```elixir
    config :flippant, adapter: Flippant.Adapters.Redix
    ```

## Usage

Flippant composes three constructs to determine whether a feature is enabled:

* Actors - An actor can be any value, but typically it is a `%User{}` or
  some other struct representing a user.
* Groups - Groups are used to identify and qualify actors. For example,
  "everybody", "nobody", "admins", "staff", "testers" could all be groups names.
* Rules - Rules represent individual features which are evaluated against actors
  and groups. For example, "search", "analytics", "super-secret-feature" could
  all be rule names.

Let's walk through setting up a few example groups and rules. You'll want to
establish groups at startup, as they aren't likely to change (and defining
functions from a web interface isn't wise).

### Groups

First, a group that nobody can belong to. This is useful for disabling a feature
without deleting it:

```elixir
Flippant.register("nobody", fn(_actor, _values) -> false end)
```

Now the opposite, a group that everybody can belong to:

```elixir
Flippant.register("everybody", fn(_actor, _values) -> true end)
```

To be more exclusive and define staff only features we need a "staff" group:

```elixir
Flippant.register("staff", fn
  nil, _values   -> false
  actor, _values -> actor.staff?
end)
```

Lastly, we'll roll out a feature out to a percentage of the actors:

```elixir
Flippant.register("adopters", fn
  _actor, []         -> false
  %{id: id}, buckets -> rem(id, 10) in buckets
end)
```

With some core groups defined we can set up some rules now.

### Rules

Rules are comprised of a name, a group, and an optional set of values. Starting
with a simple example that builds on the groups we have already created, we'll
enable the "search" feature:


```elixir
# Any staff can use the "search" feature
Flippant.enable("search", "staff")

# 30% of "adopters" can use the "search" feature as well
Flippant.enable("search", "adopters", [0, 1, 2])
```

Because rules are only built of binaries and simple data they can be defined or
refined at runtime. In fact, this is a crucial part of feature toggling. With a
web interface rules can be added, removed, or modified.

```elixir
# Turn search off for adopters
Flippant.disable("search", "adopters")

# On second thought, enable it again for 10%
Flippant.enable("search", "adopters", [3])
```

With a set of groups and rules defined we can check whether a feature is
enabled for a particular actor:

```elixir
staff_user = %User{id: 1, staff?: true}
early_user = %User{id: 2, staff?: false}
later_user = %User{id: 3, staff?: false}

Flippant.enabled?("search", staff_user) #=> true, staff
Flippant.enabled?("search", early_user) #=> false, not an adopter
Flippant.enabled?("search", later_user) #=> true, is an adopter
```

If an actor qualifies for multiple groups and *any* of the rules evaluate to
true that feature will be enabled for them. Think of the "nobody" and
"everybody" groups that were defined earlier:

```elixir
Flippant.enable("search", "everybody")
Flippant.enable("search", "nobody")

Flippant.enabled?("search", %User{}) #=> true
```

## Breakdown

Evaluating rules requires a round trip to the database. Clearly, with a lot of
rules it is inefficient to evaluate each one individually. There is a function
to help with this exact scenario:

```elixir
Flippant.enable("search", "staff")
Flippant.enable("delete", "everybody")
Flippant.enable("invite", "nobody")

Flippant.breakdown(%User{id: 1, staff?: true}) #=> %{
  "search" => true,
  "delete" => true,
  "invite" => false
}
```

The breakdown is a simple map of binary keys to boolean values. This is
extremely handy for single page applications where you can serialize the
breakdown on boot or send it back from an endpoint as JSON.

## Configuring Groups

Group definitions are stored in a process, which requires the Flippant
application to be started. That means they can't be defined within a
configuration file and should instead be linked from `Application.start/2`.
You can make `Flippant.register/2` calls directly from the application
module, or put them into a separate module and start it as a temporary worker.

```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(MyApp.Flippant, [], restart: :temporary)
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
```

Here you can see the worker was defined with `restart: :temporary`. Now, within
the `MyApp.Flippant` module:

```elixir
defmodule MyApp.Flippant do
  def start_link do
    Flippant.register("nobody", &nobody?/2)
    Flippant.register("everybody", &everybody?/2)

    :ignore
  end

  def nobody?(_, _), do: false
  def everybody?(_, _), do: true
end
```

## Testing

To avoid touching Redis while testing you can use the `Memory` adapter. Within
`config/test.exs` override the `:adapter`:

```elixir
config :flippant, adapter: Flippant.Adapters.Memory
```

The memory adapter behaves identically but will clear out whenever the
application is restarted.

## Customizing Value Serialization

As seen above in [Usage][], it is possible to store a value along with a rule.
Values can be any type of data structure, including lists, maps, or even
modules. This adds a great deal of additional power to group evaluation, but it
means that the values must be serialized in a high fidelity way.

By default, values are stored using Erlang's [binary term storage][btt]. This
works perfectly fine, but isn't especially readable and isn't compatible with
other languages. If you'd prefer to use `JSON` or `MessagePack` instead you can
provide a custom serializer and configure Flippant to use that instead. For
example, to use MessagePack via the `Msgpax` libary:

```elixir
defmodule MyApp.Serializer do
  @behaviour Flippant.Serializer

  def dump(value), do: Msgpax.pack!(value)
  def load(value), do: Msgpax.unpack!(value)
end
```

Then, within `config.exs` set the serializer:

```elixir
config :flippant, serializer: MyApp.Serializer
```

[btt]: http://erlang.org/doc/man/erlang.html#binary_to_term-1

## License

MIT License, see [LICENSE.txt](LICENSE.txt) for details.
