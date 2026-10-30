defmodule AfyaFitWeb.TimeHelpers do
  @moduledoc """
  Showing stored UTC times in the viewer's time zone. Imported into every
  LiveView and template; pass the `@current_scope`.
  """

  alias AfyaFit.Timezone

  @doc """
  An instant formatted with `Calendar.strftime/2` patterns in the scope's zone.
  `nil` stays `nil`, so optional times need no guard.
  """
  def local(datetime, scope, pattern),
    do: Timezone.format(datetime, Timezone.zone(scope), pattern)

  @doc "The date it is now for the scope's user."
  def local_today(scope), do: scope |> Timezone.zone() |> Timezone.today()
end
