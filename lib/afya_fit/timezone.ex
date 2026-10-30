defmodule AfyaFit.Timezone do
  @moduledoc """
  Time zones for people: every instant is stored in UTC, and shown or entered in
  the viewer's `timezone` (an IANA name such as `Africa/Nairobi`).

  Anything that decides which *day* something belongs to ("today", reminders)
  must go through here, not through `Date.utc_today/0`, or an evening in Nairobi
  lands on tomorrow.
  """

  alias AfyaFit.Authorization.Scope

  @default "UTC"

  # Offered in the settings picker. Any valid IANA name is accepted elsewhere
  # (the browser's own zone is adopted as reported).
  @common ~w(
    Africa/Nairobi Africa/Kampala Africa/Dar_es_Salaam Africa/Addis_Ababa Africa/Kigali
    Africa/Lagos Africa/Accra Africa/Johannesburg Africa/Cairo Africa/Casablanca
    Europe/London Europe/Paris Europe/Berlin Europe/Istanbul Asia/Dubai Asia/Kolkata
    Asia/Singapore Asia/Tokyo Australia/Sydney Pacific/Auckland
    America/New_York America/Chicago America/Denver America/Los_Angeles America/Sao_Paulo UTC
  )

  def default, do: @default

  @doc "Zones offered in the settings picker."
  def common, do: @common

  @doc "The picker's choices, with `current` included even when it is not common."
  def choices(current) do
    zones = if current in @common or not valid?(current), do: @common, else: [current | @common]
    Enum.map(zones, &{String.replace(&1, "_", " "), &1})
  end

  @doc "Whether `zone` is a time zone name we can convert to."
  @spec valid?(term()) :: boolean()
  def valid?(zone) when is_binary(zone) do
    match?({:ok, _}, DateTime.shift_zone(~U[2026-01-01 00:00:00Z], zone))
  end

  def valid?(_zone), do: false

  @doc "The zone of a user or scope; `UTC` when it is missing or unusable."
  @spec zone(Scope.t() | map() | nil) :: String.t()
  def zone(%Scope{user: user}), do: zone(user)
  def zone(%{timezone: zone}) when is_binary(zone), do: if(valid?(zone), do: zone, else: @default)
  def zone(_other), do: @default

  @doc "The instant as wall-clock time in `zone`."
  @spec to_local(DateTime.t(), String.t()) :: DateTime.t()
  def to_local(%DateTime{} = datetime, zone) do
    case DateTime.shift_zone(datetime, zone) do
      {:ok, local} -> local
      {:error, _reason} -> datetime
    end
  end

  @doc "The calendar date it currently is in `zone`."
  @spec today(String.t(), DateTime.t()) :: Date.t()
  def today(zone, now \\ DateTime.utc_now()), do: now |> to_local(zone) |> DateTime.to_date()

  @doc "The local date of an instant."
  @spec local_date(DateTime.t(), String.t()) :: Date.t()
  def local_date(%DateTime{} = datetime, zone),
    do: datetime |> to_local(zone) |> DateTime.to_date()

  @doc "Formats an instant in `zone` with `Calendar.strftime/2` patterns."
  @spec format(DateTime.t() | nil, String.t(), String.t()) :: String.t() | nil
  def format(nil, _zone, _pattern), do: nil

  def format(%DateTime{} = datetime, zone, pattern),
    do: datetime |> to_local(zone) |> Calendar.strftime(pattern)

  @doc """
  Reads an ISO 8601 time. One with an offset (`...Z`, `...+03:00`) is an exact
  instant; one without is wall-clock time in `zone`. A time that happens twice
  (clocks going back) takes the first; one that never happens (clocks going
  forward) takes the moment after the gap.
  """
  @spec parse(String.t(), String.t()) :: {:ok, DateTime.t()} | :error
  def parse(string, zone) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, instant, _offset} ->
        {:ok, DateTime.shift_zone!(instant, "Etc/UTC")}

      {:error, _reason} ->
        with {:ok, naive} <- NaiveDateTime.from_iso8601(string),
             {:ok, utc} <- localize(naive, zone) do
          {:ok, utc}
        else
          _ -> :error
        end
    end
  end

  def parse(_string, _zone), do: :error

  defp localize(naive, zone) do
    case DateTime.from_naive(naive, zone) do
      {:ok, local} -> DateTime.shift_zone(local, "Etc/UTC")
      {:ambiguous, first, _second} -> DateTime.shift_zone(first, "Etc/UTC")
      {:gap, _before, after_gap} -> DateTime.shift_zone(after_gap, "Etc/UTC")
      {:error, _reason} -> :error
    end
  end
end
