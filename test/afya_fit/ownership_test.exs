defmodule AfyaFit.OwnershipTest do
  use ExUnit.Case, async: true

  alias AfyaFit.Accounts.User
  alias AfyaFit.Nutrition.NutritionPlan
  alias AfyaFit.Ownership
  alias AfyaFit.Schedule.CalendarEvent
  alias AfyaFit.Tasks.Task
  alias AfyaFit.Tracking.ProgressEntry
  alias AfyaFit.Workouts.{ClientWorkout, WorkoutPlan}

  test "without/2 drops atom and string keys" do
    assert Ownership.without(%{"a" => 1, b: 2, c: 3}, [:a, :b]) == %{c: 3}
  end

  # {schema, ownership fields, a valid record}
  @cases [
    {WorkoutPlan, [:organization_id, :trainer_id], %WorkoutPlan{name: "Plan"}},
    {NutritionPlan, [:organization_id, :trainer_id], %NutritionPlan{name: "Plan"}},
    {Task, [:organization_id, :trainer_id, :client_id], %Task{title: "T"}},
    {CalendarEvent, [:organization_id, :user_id], %CalendarEvent{title: "E"}},
    {ClientWorkout, [:client_id, :assigned_by], %ClientWorkout{}},
    {ProgressEntry, [:client_id, :trainer_id], %ProgressEntry{}}
  ]

  for {schema, fields, record} <- @cases, field <- fields do
    test "#{inspect(schema)}.update_changeset/2 cannot change #{field}" do
      other = Ecto.UUID.generate()
      record = unquote(Macro.escape(record))

      for attrs <- [%{unquote(field) => other}, %{unquote(Atom.to_string(field)) => other}] do
        changeset = unquote(schema).update_changeset(record, attrs)

        refute Map.has_key?(changeset.changes, unquote(field))
      end
    end
  end

  test "a client's profile changeset cannot change role, organization or credentials" do
    changeset =
      User.profile_changeset(%User{email: "a@b.co", first_name: "A", last_name: "B"}, %{
        "role" => "admin",
        "organization_id" => Ecto.UUID.generate(),
        "password_hash" => "x",
        "first_name" => "Renamed"
      })

    assert changeset.changes == %{first_name: "Renamed"}
  end
end
