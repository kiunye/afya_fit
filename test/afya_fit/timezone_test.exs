defmodule AfyaFit.TimezoneTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Accounts
  alias AfyaFit.Accounts.User
  alias AfyaFit.Timezone

  describe "valid?/1" do
    test "accepts IANA names and rejects the rest" do
      assert Timezone.valid?("Africa/Nairobi")
      assert Timezone.valid?("UTC")
      refute Timezone.valid?("Mars/Olympus")
      refute Timezone.valid?("")
      refute Timezone.valid?(nil)
    end
  end

  describe "zone/1" do
    test "reads users and scopes, falling back to UTC" do
      assert Timezone.zone(%User{timezone: "Africa/Nairobi"}) == "Africa/Nairobi"
      assert Timezone.zone(%User{timezone: "Nowhere/Land"}) == "UTC"
      assert Timezone.zone(nil) == "UTC"
      assert Timezone.zone(%{user: nil}) == "UTC"
    end
  end

  describe "days" do
    test "an evening in UTC is already tomorrow in Nairobi" do
      late = ~U[2026-10-30 21:30:00Z]

      assert Timezone.today("UTC", late) == ~D[2026-10-30]
      assert Timezone.today("Africa/Nairobi", late) == ~D[2026-10-31]
      assert Timezone.local_date(late, "Africa/Nairobi") == ~D[2026-10-31]
    end

    test "and still yesterday in New York" do
      early = ~U[2026-10-30 02:00:00Z]

      assert Timezone.today("America/New_York", early) == ~D[2026-10-29]
    end
  end

  describe "format/3" do
    test "shows the instant on the viewer's clock" do
      instant = ~U[2026-10-30 21:30:00Z]

      assert Timezone.format(instant, "Africa/Nairobi", "%-d %b, %H:%M") == "31 Oct, 00:30"
      assert Timezone.format(instant, "UTC", "%H:%M") == "21:30"
    end

    test "nothing stays nothing" do
      assert Timezone.format(nil, "Africa/Nairobi", "%H:%M") == nil
    end
  end

  describe "parse/2" do
    test "a time with an offset is exact, whatever the zone" do
      assert {:ok, ~U[2026-10-30 07:00:00Z]} =
               Timezone.parse("2026-10-30T10:00:00+03:00", "America/New_York")

      assert {:ok, ~U[2026-10-30 10:00:00Z]} =
               Timezone.parse("2026-10-30T10:00:00Z", "Africa/Nairobi")
    end

    test "a time without one is the wall clock in the user's zone" do
      assert {:ok, ~U[2026-10-30 07:00:00Z]} =
               Timezone.parse("2026-10-30T10:00:00", "Africa/Nairobi")
    end

    test "clocks going back: the first of the two takes it" do
      # London, 25 Oct 2026: 01:30 happens at 00:30Z and again at 01:30Z.
      assert {:ok, ~U[2026-10-25 00:30:00Z]} =
               Timezone.parse("2026-10-25T01:30:00", "Europe/London")
    end

    test "clocks going forward: a time that never happens moves past the gap" do
      # London, 29 Mar 2026: 01:30 does not exist; the clock jumps 01:00 to 02:00.
      assert {:ok, ~U[2026-03-29 01:00:00Z]} =
               Timezone.parse("2026-03-29T01:30:00", "Europe/London")
    end

    test "rubbish is an error" do
      assert :error = Timezone.parse("tomorrow-ish", "Africa/Nairobi")
      assert :error = Timezone.parse(nil, "Africa/Nairobi")
    end
  end

  describe "choices/1" do
    test "lists common zones, adding an uncommon current one" do
      assert {"Africa/Nairobi" |> String.replace("_", " "), "Africa/Nairobi"} in Timezone.choices(
               "UTC"
             )

      assert {"Asia/Kathmandu", "Asia/Kathmandu"} in Timezone.choices("Asia/Kathmandu")
      refute Enum.any?(Timezone.choices("Mars/Olympus"), &(elem(&1, 1) == "Mars/Olympus"))
    end
  end

  describe "adopting the browser's zone" do
    setup do
      %{user: user(organization(), :trainer)}
    end

    test "someone with no zone yet takes the one the browser reports", %{user: user} do
      assert user.timezone == nil
      assert Timezone.zone(user) == "UTC"

      assert {:ok, %User{timezone: "Africa/Nairobi"}} =
               Accounts.adopt_timezone(user, "Africa/Nairobi")
    end

    test "a zone they chose is never overwritten", %{user: user} do
      {:ok, chosen} = Accounts.update_timezone(user, "Europe/London")

      assert {:ok, %User{timezone: "Europe/London"}} =
               Accounts.adopt_timezone(chosen, "Africa/Nairobi")
    end

    test "choosing UTC is a choice too, and is kept", %{user: user} do
      {:ok, chosen} = Accounts.update_timezone(user, "UTC")

      assert {:ok, %User{timezone: "UTC"}} = Accounts.adopt_timezone(chosen, "Africa/Nairobi")
    end

    test "an unknown zone, or none, changes nothing", %{user: user} do
      assert {:ok, %User{timezone: nil}} = Accounts.adopt_timezone(user, "Mars/Olympus")
      assert {:ok, %User{timezone: nil}} = Accounts.adopt_timezone(user, nil)
    end
  end

  describe "changing the zone" do
    test "saves a valid one and refuses an invalid one" do
      user = user(organization(), :client)

      assert {:ok, %User{timezone: "Africa/Lagos"}} =
               Accounts.update_timezone(user, "Africa/Lagos")

      assert {:error, changeset} = Accounts.update_timezone(user, "Nowhere/Land")
      assert %{timezone: ["is not a time zone we know"]} = errors_on(changeset)
    end

    test "registration refuses an unknown zone" do
      org = organization()

      assert {:error, changeset} =
               Accounts.register_with_organization(%{
                 "role" => "client",
                 "organization_subdomain" => org.subdomain,
                 "email" => "tz@example.com",
                 "password" => "a-long-enough-password",
                 "first_name" => "Tz",
                 "last_name" => "Test",
                 "timezone" => "Nowhere/Land"
               })

      assert %{timezone: _} = errors_on(changeset)
    end
  end
end
