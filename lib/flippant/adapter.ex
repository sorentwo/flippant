defmodule Flippant.Adapter do
  import Kernel, except: [defdelegate: 2]

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
