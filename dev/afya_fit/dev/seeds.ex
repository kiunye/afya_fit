defmodule AfyaFit.Dev.Seeds do
  @moduledoc """
  Demo data for development and manual testing: a handful of organisations that
  each sit in a different billing state, with people, plans, tasks, progress,
  events, invoices and payments to look at. Run it with

      mix run priv/repo/seeds.exs

  It is safe to run again: people, organisations and plans are found before
  they are created, and each run puts every organisation back into its billing
  state (dates are relative to now, so "overdue" stays overdue). This module is
  only compiled in development and test, so it cannot ship.

  Every account's password is `password/0`; the emails are in `docs/dev.md` and
  printed by `mix run priv/repo/seeds.exs`.
  """

  import Ecto.Query

  alias AfyaFit.Accounts.{TrainerClient, User}
  alias AfyaFit.Billing
  alias AfyaFit.Billing.{Invoice, Payment}
  alias AfyaFit.{Nutrition, Organizations, Repo, Schedule, Tasks, Timezone, Tracking, Workouts}
  alias AfyaFit.Organizations.Organization

  @password "demo-password-123"
  @pool ~w(Otieno Amina Kamau Zawadi Juma Neema Baraka Imani Faraji Sauti Tumaini Wambui Njeri Mwangi
           Achieng Kiprono Chebet Omondi Nyambura Mutua Akinyi Kariuki Wekesa Naliaka)
  @surnames ~w(Odhiambo Hassan Mwangi Wanjiru Otieno Kamau Achieng Kiplagat Mutiso Barasa Njoroge
               Onyango Chepkoech Maina Abdalla Ndungu Waweru Okello Kimani Mohamed Gitau Owino
               Ruto Langat Wafula)

  def password, do: @password

  @doc "Builds (or refreshes) all the demo data. Returns the accounts it made, for display."
  def run do
    AfyaFit.RLS.unscoped(fn ->
      admin = person(organization(hq()), "admin", "Platform", "Admin", "admin@afyafit.test")

      accounts = for spec <- specs(), do: build(spec)
      %{admin: admin, organizations: accounts}
    end)
  end

  ## The organisations

  defp hq, do: %{name: "Afya Fit HQ", subdomain: "afya-fit-hq", plan: "enterprise"}

  defp specs do
    [
      %{
        name: "Njoroge Strength",
        subdomain: "njoroge-strength",
        domain: "njoroge.test",
        plan: "free",
        state: "Free plan, at its 3-client limit, one client archived",
        owner: {"Wanjiru", "Njoroge", "Africa/Nairobi"},
        trainers: [],
        clients: [:active, :active, :active, :archived],
        content: true
      },
      %{
        name: "Peak Performance Gym",
        subdomain: "peak-performance",
        domain: "peak.test",
        plan: "pro",
        billing: {:active, 10},
        state: "Pro, paid and healthy; the fullest data",
        owner: {"Brian", "Kariuki", "Africa/Nairobi"},
        trainers: [{"Amina", "Hassan", "Africa/Nairobi"}, {"Faith", "Clarke", "Europe/London"}],
        clients: [
          :active,
          :active,
          :active,
          :active,
          :active,
          :active,
          :paused,
          :paused,
          :archived,
          :active
        ],
        content: true,
        payments: true
      },
      %{
        name: "Titan Fitness Collective",
        subdomain: "titan-fitness",
        domain: "titan.test",
        plan: "enterprise",
        billing: {:active, 5},
        state: "Enterprise, unlimited clients",
        owner: {"Grace", "Mutiso", "Africa/Nairobi"},
        trainers: [{"Kevin", "Barasa", nil}],
        clients: [:active, :active, :active, :active, :active],
        content: false
      },
      %{
        name: "Grace Period Gym",
        subdomain: "grace-period",
        domain: "grace.test",
        plan: "pro",
        billing: {:active, 33},
        state: "Pro, period ended 3 days ago: inside the 7-day grace period",
        owner: {"Daniel", "Maina", "Africa/Nairobi"},
        trainers: [],
        clients: [:active, :active],
        content: false
      },
      %{
        name: "Lapsed Fitness",
        subdomain: "lapsed-fitness",
        domain: "lapsed.test",
        plan: "pro",
        billing: {:active, 42},
        state: "Pro, period ended 12 days ago: read-only until it pays",
        owner: {"Esther", "Ndungu", "Africa/Nairobi"},
        trainers: [],
        clients: [:active, :active],
        content: false
      },
      %{
        name: "Leaving Studio",
        subdomain: "leaving-studio",
        domain: "leaving.test",
        plan: "pro",
        billing: {:cancelled_at_period_end, 20},
        state: "Pro, cancelled: keeps access until the period ends",
        owner: {"Peter", "Okello", "Africa/Nairobi"},
        trainers: [],
        clients: [:active],
        content: false
      },
      %{
        name: "Suspended Club",
        subdomain: "suspended-club",
        domain: "suspended.test",
        plan: "pro",
        status: "suspended",
        billing: {:active, 5},
        state: "Suspended by a platform admin: read-only",
        owner: {"Lucy", "Wafula", "Africa/Nairobi"},
        trainers: [],
        clients: [:active],
        content: false
      }
    ]
  end

  ## Building one organisation

  defp build(spec) do
    org = organization(spec)
    {first, last, zone} = spec.owner

    owner =
      person(org, "org_admin", first, last, "#{String.downcase(first)}@#{spec.domain}", zone)

    trainers =
      for {first, last, zone} <- spec.trainers,
          do:
            person(org, "trainer", first, last, "#{String.downcase(first)}@#{spec.domain}", zone)

    coaches = [owner | trainers]
    billing(org, spec[:billing])

    clients =
      spec.clients
      |> Enum.with_index()
      |> Enum.map(fn {status, i} -> client(org, spec.domain, coaches, i, status) end)

    if spec[:content], do: content(org, hd(trainers ++ [owner]), clients)
    if spec[:payments], do: payments(org, owner)

    %{
      name: spec.name,
      state: spec.state,
      owner: owner.email,
      trainers: Enum.map(trainers, & &1.email),
      clients: Enum.map(clients, & &1.email)
    }
  end

  defp organization(spec) do
    attrs = %{
      name: spec.name,
      subdomain: spec.subdomain,
      plan_type: spec.plan,
      status: Map.get(spec, :status, "active")
    }

    case Repo.get_by(Organization, subdomain: spec.subdomain) do
      nil -> Organizations.create_organization(attrs) |> elem(1)
      existing -> Organizations.update_organization(existing, attrs) |> elem(1)
    end
  end

  defp person(org, role, first, last, email, zone \\ nil) do
    case Repo.get_by(User, email: email) do
      nil ->
        %User{}
        |> User.registration_changeset(%{
          "email" => email,
          "password" => @password,
          "first_name" => first,
          "last_name" => last,
          "role" => if(role == "org_admin", do: "trainer", else: role),
          "organization_id" => org.id,
          "phone" => "07#{:rand.uniform(89_999_999) + 10_000_000}",
          "timezone" => zone
        })
        |> Ecto.Changeset.put_change(:role, role)
        |> Repo.insert!()

      existing ->
        existing
    end
  end

  defp client(org, domain, coaches, i, status) do
    first = Enum.at(@pool, rem(org_seed(org) + i, length(@pool)))
    last = Enum.at(@surnames, rem(org_seed(org) * 3 + i * 5, length(@surnames)))
    email = "#{String.downcase(first)}.#{String.downcase(last)}@#{domain}"
    zone = if rem(i, 4) == 3, do: "Africa/Nairobi", else: nil
    client = person(org, "client", first, last, email, zone)
    coach = Enum.at(coaches, rem(i, length(coaches)))

    link_status = if status == :active, do: "active", else: Atom.to_string(status)
    link(coach, client, link_status)
    client
  end

  defp org_seed(%Organization{name: name}), do: :erlang.phash2(name, 20)

  defp link(trainer, client, status) do
    ended = if status == "archived", do: now(), else: nil

    case Repo.get_by(TrainerClient, trainer_id: trainer.id, client_id: client.id) do
      nil ->
        Repo.insert!(%TrainerClient{
          trainer_id: trainer.id,
          client_id: client.id,
          status: status,
          started_at: DateTime.add(now(), -45, :day),
          ended_at: ended
        })

      existing ->
        existing |> Ecto.Changeset.change(status: status, ended_at: ended) |> Repo.update!()
    end
  end

  ## Billing: periods are relative to now so the state does not drift

  defp billing(_org, nil), do: :ok

  defp billing(org, {kind, days_ago}) do
    started = DateTime.add(now(), -days_ago, :day)
    {:ok, subscription} = Billing.put_plan(org, org.plan_type, 30, now: started)

    if kind == :cancelled_at_period_end, do: {:ok, _} = Billing.cancel_subscription(subscription)
    :ok
  end

  ## Things to look at

  defp content(org, trainer, clients) do
    plans = workouts(org, trainer)
    nutrition(org, trainer, clients)

    for {client, i} <- Enum.with_index(clients) do
      plan = Enum.at(plans, rem(i, length(plans)))
      assign_workout(trainer, client, plan, i)
      tasks(org, trainer, client)
      progress(trainer, client, i)
    end

    events(org, trainer)
  end

  defp workouts(org, trainer) do
    for {name, difficulty, moves} <- [
          {"Lower body strength", "intermediate",
           [{"Back squat", 4, "6"}, {"Romanian deadlift", 3, "8"}]},
          {"Upper body push", "beginner", [{"Bench press", 4, "8"}, {"Overhead press", 3, "10"}]},
          {"Conditioning circuit", "advanced",
           [{"Burpees", 5, "12"}, {"Kettlebell swing", 4, "15"}]}
        ] do
      plan =
        Repo.get_by(AfyaFit.Workouts.WorkoutPlan, organization_id: org.id, name: name) ||
          elem(
            Workouts.create_workout_plan(%{
              name: name,
              organization_id: org.id,
              trainer_id: trainer.id,
              difficulty: difficulty,
              duration_weeks: 6,
              is_public: true
            }),
            1
          )

      add_moves(plan, moves)
      plan
    end
  end

  defp add_moves(plan, moves) do
    existing =
      Repo.aggregate(
        from(w in AfyaFit.Workouts.WorkoutExercise, where: w.workout_plan_id == ^plan.id),
        :count
      )

    if existing == 0 do
      for {{name, sets, reps}, i} <- Enum.with_index(moves) do
        Workouts.create_workout_exercise(%{
          workout_plan_id: plan.id,
          exercise_name: name,
          sets: sets,
          reps: reps,
          rest_seconds: 90,
          order_index: i,
          day_number: 1
        })
      end
    end
  end

  defp assign_workout(trainer, client, plan, i) do
    unless Repo.get_by(AfyaFit.Workouts.ClientWorkout,
             client_id: client.id,
             workout_plan_id: plan.id
           ) do
      today = Timezone.today(Timezone.zone(client))

      Workouts.create_client_workout(%{
        client_id: client.id,
        workout_plan_id: plan.id,
        assigned_by: trainer.id,
        assigned_date: Date.add(today, -3),
        start_date: Date.add(today, rem(i, 3) - 1),
        status: if(rem(i, 4) == 0, do: "completed", else: "assigned")
      })
    end
  end

  defp nutrition(org, trainer, clients) do
    for {client, i} <- Enum.with_index(Enum.take(clients, 2)) do
      name = "Lean bulk plan #{i + 1}"

      unless Repo.get_by(AfyaFit.Nutrition.NutritionPlan, organization_id: org.id, name: name) do
        {:ok, plan} =
          Nutrition.create_nutrition_plan(%{
            name: name,
            organization_id: org.id,
            trainer_id: trainer.id,
            client_id: client.id,
            daily_calories: 2600 + i * 200,
            macros: %{"protein" => 160, "carbs" => 300, "fat" => 70},
            start_date: Date.utc_today(),
            end_date: Date.add(Date.utc_today(), 28)
          })

        for {meal, type, kcal} <- [
              {"Oats and banana", "breakfast", 520},
              {"Ugali, beef stew and greens", "lunch", 780}
            ] do
          Nutrition.create_nutrition_meal(%{
            nutrition_plan_id: plan.id,
            meal_type: type,
            name: meal,
            calories: kcal,
            order_index: 0,
            day_number: 1
          })
        end
      end
    end
  end

  defp tasks(org, trainer, client) do
    for {title, offset_hours, status} <- [
          {"Log this week's measurements", -26, "pending"},
          {"Book a form check", 20, "pending"},
          {"Drink 3 litres of water daily", -72, "completed"}
        ] do
      unless Repo.get_by(AfyaFit.Tasks.Task, client_id: client.id, title: title) do
        Tasks.create_task(%{
          organization_id: org.id,
          trainer_id: trainer.id,
          client_id: client.id,
          title: title,
          task_type: "general",
          status: status,
          due_date: DateTime.add(now(), offset_hours, :hour),
          completed_at: if(status == "completed", do: now())
        })
      end
    end
  end

  defp progress(trainer, client, i) do
    for week <- 0..5 do
      date = Date.add(Date.utc_today(), -7 * week)

      unless Repo.get_by(AfyaFit.Tracking.ProgressEntry, client_id: client.id, entry_date: date) do
        Tracking.create_progress_entry(%{
          client_id: client.id,
          trainer_id: trainer.id,
          entry_date: date,
          weight: Decimal.from_float(70.0 + i + week * 0.4),
          body_fat_percentage: Decimal.from_float(20.0 - week * 0.2),
          notes: if(week == 0, do: "Feeling strong this week.")
        })
      end
    end
  end

  # Times are the trainer's own wall clock, so they show up on the right day:
  # one is half past eleven at night, which is already tomorrow in UTC terms.
  defp events(org, trainer) do
    zone = Timezone.zone(trainer)
    today = Timezone.today(zone)

    for {title, day, time} <- [
          {"Check-in: first client of the day", 0, "09:00:00"},
          {"Group conditioning", 0, "18:00:00"},
          {"Late call with a night-shift client", 0, "23:30:00"},
          {"Programme review", 1, "08:00:00"}
        ] do
      {:ok, start} = Timezone.parse("#{Date.add(today, day)}T#{time}", zone)

      unless Repo.get_by(AfyaFit.Schedule.CalendarEvent,
               user_id: trainer.id,
               title: title,
               start_time: DateTime.truncate(start, :second)
             ) do
        Schedule.create_calendar_event(%{
          organization_id: org.id,
          user_id: trainer.id,
          title: title,
          event_type: "appointment",
          start_time: DateTime.truncate(start, :second),
          end_time: DateTime.add(DateTime.truncate(start, :second), 3600, :second),
          timezone: zone
        })
      end
    end
  end

  ## Payments and invoices for the organisation that has paid

  defp payments(org, owner) do
    subscription = Billing.get_subscription_by_organization(org.id)

    for {n, status} <- [{"1", "succeeded"}, {"2", "succeeded"}] do
      number = "INV-SEED-0000#{n}"

      unless Repo.get_by(Invoice, invoice_number: number) do
        Repo.insert!(%Invoice{
          subscription_id: subscription.id,
          invoice_number: number,
          amount: Decimal.new(1500),
          currency: "KES",
          status: "paid",
          due_date: Date.add(Date.utc_today(), -30 * String.to_integer(n)),
          paid_at: DateTime.add(now(), -30 * String.to_integer(n), :day)
        })
      end

      payment(org, owner, "SEED-#{status}-#{n}", "paystack", status)
    end

    payment(org, owner, "SEED-mpesa-ok", "daraja", "succeeded", "254712345678")
    payment(org, owner, "SEED-mpesa-failed", "daraja", "failed", "254722345670")
    payment(org, owner, "SEED-mpesa-waiting", "daraja", "pending", "254733345678")
  end

  defp payment(org, owner, reference, provider, status, phone \\ nil) do
    unless Repo.get_by(Payment, reference: reference) do
      %Payment{}
      |> Payment.create_changeset(%{
        organization_id: org.id,
        user_id: owner.id,
        provider: provider,
        plan_type: "pro",
        amount: Decimal.new(1500),
        reference: reference,
        phone: phone,
        callback_token: if(provider == "daraja", do: "seed-token-#{reference}")
      })
      |> Repo.insert!()
      |> Payment.update_changeset(%{
        status: status,
        provider_reference: if(provider == "daraja", do: "ws_CO_#{reference}"),
        receipt: if(status == "succeeded", do: "SEED#{:erlang.phash2(reference)}"),
        failure_reason: if(status == "failed", do: "Request cancelled by user"),
        paid_at: if(status == "succeeded", do: now())
      })
      |> Repo.update!()
    end
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
