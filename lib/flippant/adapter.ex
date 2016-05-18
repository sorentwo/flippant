defmodule Flippant.Adapter do
  import Kernel, except: [defdelegate: 2]

  @callback add(String.t) :: :ok
  @callback breakdown(any) :: Map.t
  @callback enable(String.t, String.t) :: :ok
  @callback enable(String.t, String.t, any) :: :ok
  @callback enabled?(String.t, any) :: boolean
  @callback disable(String.t, String.t) :: :ok
  @callback features :: list
  @callback features(String.t) :: list
  @callback remove(String.t) :: :ok

  defmacro defdelegate(funs) do
    funs = Macro.escape(funs, unquote: true)

    quote bind_quoted: [funs: funs] do
      for fun <- List.wrap(funs) do
        {name, args, as, as_args} = Kernel.Utils.defdelegate(fun, [], __ENV__)

        def unquote(name)(unquote_splicing(args)) do
          Flippant.Adapter.adapter().unquote(as)(unquote_splicing(as_args))
        end
      end
    end
  end

  def adapter do
    Application.get_env(:flippant, :adapter)
  end
end
