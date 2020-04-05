defmodule Flippant do
  @moduledoc """
  Feature toggling for Elixir applications.

  Flippant defines features in terms of `actors`, `groups`, and `rules`:

  * **Actors** - Typically an actor is a `%User{}` or some other persistent
    struct that identifies who is using your application.
  * **Groups** - Groups identify and qualify actors. For example, the `admins`
    group would identify actors that are admins, while `beta-testers` may
    identify a few actors that are testing a feature. It is entirely up to you
    to define groups in your application.
  * **Rules** - Rules bind groups with individual features. These are evaluated
    against actors to see if a feature should be enabled.

  Let's walk through setting up a few groups and rules.

  ### Groups

  First, a group that nobody can belong to. This is useful for disabling a
  feature without deleting it. Groups are registered with a `name` and an
  evalutation `function`. In this case the name of our group is "nobody",
  and the function always returns `false`:

      Flippant.register("nobody", fn(_actor, _values) -> false end)

  Now the opposite, a group that everybody can belong to:

      Flippant.register("everybody", fn(_actor, _values) -> true end)

  To be more specific and define staff only features we define a "staff" group:

      Flippant.register("staff", fn
        %User{staff?: staff?}, _values -> staff?
      end)

  Lastly, we'll roll out a feature out to a percentage of the actors. It
  expects a list of integers between `1` and `10`. If the user's id modulo `10`
  is in the list, then the feature is enabled:

      Flippant.register("adopters", fn
        _actor, [] -> false
        %User{id: id}, samples -> rem(id, 10) in samples
      end)

  With some core groups defined we can set up some rules now.

  ### Rules

  Rules are comprised of a name, a group, and an optional set of values. Starting
  with a simple example that builds on the groups we have already created, we'll
  enable the "search" feature:

      # Any staff can use the "search" feature
      Flippant.enable("search", "staff")

      # 30% of "adopters" can use the "search" feature as well
      Flippant.enable("search", "adopters", [0, 1, 2])

  Because rules are built of binaries and simple data they can be defined or
  refined at runtime. In fact, this is a crucial part of feature toggling.
  Rules can be added, removed or modified at runtime.

      # Turn search off for adopters
      Flippant.disable("search", "adopters")

      # On second thought, enable it again for 10% of users
      Flippant.enable("search", "adopters", [3])

  With a set of groups and rules defined we can check whether a feature is
  enabled for a particular actor:

      staff_user = %User{id: 1, staff?: true}
      early_user = %User{id: 2, staff?: false}
      later_user = %User{id: 3, staff?: false}

      Flippant.enabled?("search", staff_user) #=> true, staff
      Flippant.enabled?("search", early_user) #=> false, not an adopter
      Flippant.enabled?("search", later_user) #=> true, is an adopter

  If an actor qualifies for multiple groups and *any* of the rules evaluate to
  true that feature will be enabled for them. Think of the "nobody" and
  "everybody" groups that were defined earlier:

      Flippant.enable("search", "everybody")
      Flippant.enable("search", "nobody")

      Flippant.enabled?("search", %User{}) #=> true

  ### Breakdown

  Evaluating rules requires a round trip to the database. Clearly, with a lot
  of rules it is inefficient to evaluate each one individually. The
  `breakdown/1` function helps with this scenario:

      Flippant.enable("search", "staff")
      Flippant.enable("delete", "everybody")
      Flippant.enable("invite", "nobody")

      Flippant.breakdown(%User{id: 1, staff?: true})
      #=> %{"search" => true, "delete" => true, "invite" => false}

  The breakdown is a simple map of binary keys to boolean values. This is
  particularly useful for single page applications where you can serialize the
  breakdown on boot or send it back from an endpoint as JSON.

  ### Adapters

  Feature rules are stored in adapters. Flippant comes with a few base adapters:

  * `Flippant.Adapters.Memory` - An in-memory adapter, ideal for testing (see below).
  * `Flippant.Adapters.Postgres` - A postgrex powered PostgreSQL adapter.
  * `Flippant.Adapters.Redis` - A redix powered Redis adapter.

  For adapter specific options reference the `start_link/1` function of each.

  Some adapters, notably the `Postgres` adapter, may require setup before they
  can be used. To simplify the setup process you can run `Flippant.setup()`, or
  see the adapters documentation for migration details.

  ### Testing

  Testing is simplest with the `Memory` adapter. Within `config/test.exs` override
  the `:adapter`:

      config :flippant, adapter: Flippant.Adapters.Memory

  The memory adapter will be cleared whenever the application is restarted, or
  it can be cleared between test runs using `Flippant.clear(:features)`.

  ### Defining Groups on Application Start

  Group definitions are stored in a process, which requires the Flippant
  application to be started. That means they can't be defined within a
  configuration file and should instead be linked from `Application.start/2`.
  You can make `Flippant.register/2` calls directly from the application
  module, or put them into a separate module and start it as a temporary
  worker.  Here we're starting a temporary worker with the rest of an
  application:

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

  Note that the worker is defined with `restart: :temporary`. Now, define the
  `MyApp.Flippant` module:

      defmodule MyApp.Flippant do
        def start_link do
          Flippant.register("everybody", &everybody?/2)
          Flippant.register("nobody", &nobody?/2)
          Flippant.register("staff", &staff?/2)

          :ignore
        end

        def everybody?(_, _), do: true
        def nobody?(_, _), do: false
        def staff?(%User{staff?: staff?}, _), do: staff?
      end

  ### Backups and Portability

  The `dump/1` and `load/1` functions are handy for storing feature backups on
  disk. The backup may be used to transfer features between database servers,
  or even between adapters. For example, if you've decided to move away from
  using Redis and would like to switch to Postgres instead, you could transfer
  the data with a few commands:

      # Dump from the Redis instance
      Flippant.dump("flippant.dump")

      # Restart the application
      Application.stop(:flippant)
      Application.put_env(:flippant, :adapter, Flippant.Adapter.Postgres)
      Application.ensure_started(:flippant)

      # Load to the postgres instance
      Flippant.load("flippant.dump")
  """

  # Adapter

  @doc """
  Retrieve the `pid` of the configured adapter process.

  This will return `nil` if the adapter hasn't been started.
  """
  @spec adapter() :: pid | nil
  def adapter do
    :flippant
    |> Application.fetch_env!(:adapter)
    |> Process.whereis()
  end

  @doc """
  Add a new feature without any rules.

  Adding a feature does not enable it for any groups, that can be done using
  `enable/2` or `enable/3`.

  ## Examples

      Flippant.add("search")
      #=> :ok
  """
  @spec add(binary) :: :ok
  def add(feature) when is_binary(feature) do
    GenServer.cast(adapter(), {:add, normalize(feature)})
  end

  @doc """
  Generate a mapping of all features and associated rules.

  Breakdown without any arguments defaults to `:all`, and will list all
  registered features along with their group and value metadata. It is the only
  way to retrieve a snapshot of all the features in the system. The operation
  is optimized for round-trip efficiency.

  Alternatively, breakdown takes a single `actor` argument, typically a
  `%User{}` struct or some other entity. It generates a map outlining which
  features are enabled for the actor.

  ## Examples

  Assuming the groups `awesome`, `heinous`, and `radical`, and the features
  `search`, `delete` and `invite` are enabled, the breakdown would look like:

      Flippant.breakdown()
      #=> %{"search" => %{"awesome" => [], "heinous" => []},
            "delete" => %{"radical" => []},
            "invite" => %{"heinous" => []}}

  Getting the breakdown for a particular actor:

      actor = %User{ id: 1, awesome?: true, radical?: false}
      Flippant.breakdown(actor)
      #=> %{"delete" => true, "search" => false}
  """
  @spec breakdown(map | struct | :all) :: map
  def breakdown(actor \\ :all) do
    GenServer.call(adapter(), {:breakdown, actor})
  end

  @doc """
  Purge registered features.

  This is particularly useful in testing when you want to reset to a clean
  slate after a test.

  ## Examples

      Flippant.clear()
      #=> :ok
  """
  @spec clear() :: :ok
  def clear do
    GenServer.cast(adapter(), :clear)
  end

  @doc """
  Disable a feature for a particular group.

  The feature is kept, but any rules for that group are removed.

  ## Examples

  Disable the `search` feature for the `adopters` group:

      Flippant.disable("search", "adopters")
      #=> :ok

  Alternatively, individual values may be disabled for a group. This is useful
  when a group should stay enabled and only a single value (i.e. user id) needs
  to be removed.

  Disable `search` feature for a user in the `adopters` group:

      Flippant.disable("search", "adopters", [123])
      #=> :ok
  """
  @spec disable(binary, binary) :: :ok
  def disable(feature, group, values \\ [])
      when is_binary(feature) and is_binary(group) and is_list(values) do
    GenServer.cast(adapter(), {:remove, normalize(feature), group, values})
  end

  @doc """
  Dump the full feature breakdown to a file.

  The `dump/1` command aggregates all features using `breakdown/0`, encodes
  them as json, and writes the result to a file on disk.

  Dumps are portable between adapters, so a dump may be subsequently used to
  load the data into another adapter.

  ## Examples

  Dump a daily backup:

      Flippant.dump((Date.utc_today() |> Date.to_string()) <> ".dump")
      #=> :ok
  """
  @spec dump(binary()) :: :ok | {:error, File.posix()}
  def dump(path) when is_binary(path) do
    dumped =
      adapter()
      |> GenServer.call({:breakdown, :all})
      |> Jason.encode!()

    File.write(path, dumped)
  end

  @doc """
  Enable a feature for a particular group.

  Features can be enabled for a group along with a set of values. The values
  will be passed along to the group's registered function when determining
  whether a feature is enabled for a particular actor.

  Values are useful when limiting a feature to a subset of actors by `id` or
  some other distinguishing factor. Value serialization can be customized by
  using an alternate module implementing the `Flippant.Serializer` behaviour.

  ## Examples

  Enable the `search` feature for the `radical` group, without any specific
  values:

      Flippant.enable("search", "radical")
      #=> :ok

  Assuming the group `awesome` checks whether an actor's id is in the list of
  values, you would enable the `search` feature for actors 1, 2 and 3 like
  this:

      Flippant.enable("search", "awesome", [1, 2, 3])
      #=> :ok
  """
  @spec enable(binary, binary, list(any)) :: :ok
  def enable(feature, group, values \\ [])
      when is_binary(feature) and is_binary(group) do
    GenServer.cast(adapter(), {:add, normalize(feature), {group, values}})
  end

  @doc """
  Check if a particular feature is enabled for an actor.

  If the actor belongs to any groups that have access to the feature then it
  will be enabled.

  ## Examples

      Flippant.enabled?("search", actor)
      #=> false
  """
  @spec enabled?(binary, map | struct) :: boolean
  def enabled?(feature, actor) when is_binary(feature) do
    GenServer.call(adapter(), {:enabled?, normalize(feature), actor})
  end

  @doc """
  Check whether a given feature has been registered.

  If a `group` is provided it will check whether the feature has any rules for
  that group.

  ## Examples

      Flippant.exists?("search")
      #=> false

      Flippant.add("search")
      Flippant.exists?("search")
      #=> true
  """
  @spec exists?(binary(), binary() | :any) :: boolean()
  def exists?(feature, group \\ :any) when is_binary(feature) do
    GenServer.call(adapter(), {:exists?, normalize(feature), group})
  end

  @doc """
  List all known features or only features enabled for a particular group.

  ## Examples

  Given the features `search` and `delete`:

      Flippant.features()
      #=> ["search", "delete"]

      Flippant.features(:all)
      #=> ["search", "delete"]

  If the `search` feature were only enabled for the `awesome` group:

      Flippant.features("awesome")
      #=> ["search"]
  """
  @spec features(:all | binary()) :: list(binary())
  def features(group \\ :all) do
    GenServer.call(adapter(), {:features, group})
  end

  @doc """
  Restore all features from a dump file.

  Dumped features may be restored in full using the `load/1` function. During
  the load process the file will be decoded as json.

  Loading happens atomically, but it does _not_ clear out any existing
  features. To have a clean restore you'll need to run `clear/1` first.

  ## Examples

  Restore a dump into a clean environment:

      Flippant.clear(:features) #=> :ok
      Flippant.load("backup.dump") #=> :ok
  """
  @spec load(binary()) :: :ok | {:error, File.posix() | binary()}
  def load(path) when is_binary(path) do
    with {:ok, data} <- File.read(path) do
      loaded = Jason.decode!(data)

      GenServer.cast(adapter(), {:restore, loaded})
    end
  end

  @doc """
  Rename an existing feature.

  If the new feature name already exists it will overwritten and all of the
  rules will be replaced.

  ## Examples

      Flippant.rename("search", "super-search")
      :ok
  """
  @spec rename(binary, binary) :: :ok
  def rename(old_name, new_name)
      when is_binary(old_name) and is_binary(new_name) do
    GenServer.cast(adapter(), {:rename, normalize(old_name), normalize(new_name)})
  end

  @doc """
  Fully remove a feature for all groups.

  ## Examples

      Flippant.remove("search")
      :ok
  """
  @spec remove(binary) :: :ok
  def remove(feature) when is_binary(feature) do
    GenServer.cast(adapter(), {:remove, normalize(feature)})
  end

  @doc """
  Prepare the adapter for usage.

  For adapters that don't require any setup this is a no-op. For other adapters,
  such as Postgres, which require a schema/table to operate this will create the
  necessary table.

  ## Examples

      Flippant.setup()
      :ok
  """
  @spec setup() :: :ok
  def setup do
    GenServer.cast(adapter(), :setup)
  end

  defp normalize(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.trim()
  end
end
