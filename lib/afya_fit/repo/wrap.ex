defmodule AfyaFit.Repo.Wrap do
  @moduledoc """
  Runs a module's entry points inside the tenant context RLS needs, without
  touching each function.

    * `use AfyaFit.Repo.Wrap, :job` wraps `perform/1` in `Repo.unscoped/1`
      (jobs sweep across organizations);
    * `use AfyaFit.Repo.Wrap, :live_view` wraps `mount/3`, `handle_params/3`,
      `handle_event/3` and `handle_info/2` in `Repo.with_scope/2`, using the
      socket's `current_scope`.

  It overrides the functions at compile time, so it must come after the
  `use Oban.Worker` or `use Phoenix.LiveView` it wraps. With RLS off the
  wrappers just call through.
  """

  @targets %{
    job: [perform: 1],
    live_view: [mount: 3, handle_params: 3, handle_event: 3, handle_info: 2]
  }

  defmacro __using__(kind) when kind in [:job, :live_view] do
    quote do
      @rls_wrap unquote(kind)
      @before_compile AfyaFit.Repo.Wrap
    end
  end

  defmacro __before_compile__(env) do
    kind = Module.get_attribute(env.module, :rls_wrap)

    defined =
      for {name, arity} <- Map.fetch!(@targets, kind),
          Module.defines?(env.module, {name, arity}),
          do: {name, arity}

    Module.make_overridable(env.module, defined)

    for {name, arity} <- defined do
      args = Macro.generate_arguments(arity, __MODULE__)

      quote do
        @impl true
        def unquote(name)(unquote_splicing(args)) do
          unquote(wrapper(kind, args))
        end
      end
    end
  end

  defp wrapper(:job, args) do
    quote do
      AfyaFit.Repo.unscoped(fn -> super(unquote_splicing(args)) end)
    end
  end

  defp wrapper(:live_view, args) do
    socket = List.last(args)

    quote do
      AfyaFit.Repo.with_scope(unquote(socket).assigns[:current_scope], fn ->
        super(unquote_splicing(args))
      end)
    end
  end
end
