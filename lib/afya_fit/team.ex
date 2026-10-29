defmodule AfyaFit.Team do
  @moduledoc """
  The people who coach in an organization. Organization admins add trainers and
  remove them; removing a trainer moves everything they owned to the admin and
  ends their access.
  """
  import Ecto.Query, warn: false

  alias AfyaFit.Accounts
  alias AfyaFit.Accounts.{TrainerClient, User, UserToken}
  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Nutrition.NutritionPlan
  alias AfyaFit.Repo
  alias AfyaFit.Schedule.CalendarEvent
  alias AfyaFit.Shared
  alias AfyaFit.Tasks.Task
  alias AfyaFit.Tracking.ProgressEntry
  alias AfyaFit.Workouts.{ClientWorkout, WorkoutPlan}

  @type member :: %{id: binary(), user: User.t(), client_count: non_neg_integer()}

  @doc "The organization's admins and trainers, owner first, with how many clients each coaches."
  @spec list_members(Scope.t()) :: [member()]
  def list_members(%Scope{user: %{organization_id: organization_id}}) do
    counts =
      from(tc in TrainerClient,
        where: tc.status in ["active", "paused"],
        group_by: tc.trainer_id,
        select: {tc.trainer_id, count(tc.id)}
      )
      |> Repo.all()
      |> Map.new()

    from(u in User,
      where:
        u.organization_id == ^organization_id and u.role in ["org_admin", "trainer"] and
          is_nil(u.deleted_at),
      order_by: [asc: u.role, asc: u.inserted_at]
    )
    |> Repo.all()
    |> Enum.map(&%{id: &1.id, user: &1, client_count: Map.get(counts, &1.id, 0)})
  end

  @doc "One member of the scope's organization, or `nil`."
  @spec get_member(Scope.t(), binary()) :: member() | nil
  def get_member(%Scope{} = scope, id), do: Enum.find(list_members(scope), &(&1.user.id == id))

  @doc """
  Adds a trainer and emails them a link to set a password.

  `url_fun` turns the emailed token into the link. Returns the trainer, a
  changeset when the details are invalid, or an authorization error.
  """
  @spec invite_trainer(Scope.t(), map(), (String.t() -> String.t())) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | term()}
  def invite_trainer(%Scope{} = scope, params, url_fun) when is_function(url_fun, 1) do
    with :ok <- Authorization.authorize(scope, :create, :trainer) do
      attrs = Map.take(params, ["email", "first_name", "last_name"])

      changeset =
        %User{role: "trainer", organization_id: scope.user.organization_id}
        |> User.trainer_invite_changeset(attrs)
        |> Ecto.Changeset.put_change(:password_hash, unusable_password_hash())

      Repo.transaction(fn ->
        with {:ok, trainer} <- Repo.insert(changeset),
             {:ok, _log} <- log(scope, "trainer.invited", trainer, %{email: trainer.email}) do
          trainer
        else
          {:error, error} -> Repo.rollback(error)
        end
      end)
      |> case do
        {:ok, trainer} ->
          Accounts.deliver_user_reset_password_instructions(trainer, url_fun)
          {:ok, trainer}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  @doc """
  Removes a trainer. Their clients (and the plans, tasks, events and progress
  they own) move to the acting admin, their sessions end and they can no longer
  sign in. Recorded in the activity log.
  """
  @spec remove_trainer(Scope.t(), binary()) ::
          {:ok, %{clients_moved: non_neg_integer()}} | {:error, term()}
  def remove_trainer(%Scope{user: admin} = scope, trainer_id) do
    with %User{} = trainer <- Accounts.get_user(trainer_id) || {:error, :not_found},
         :ok <- Authorization.authorize(scope, :delete, trainer),
         :ok <- ensure_trainer(trainer) do
      Repo.transaction(fn ->
        moved = move_clients(trainer, admin)
        reassign_owned(trainer, admin)
        Repo.delete_all(from t in UserToken, where: t.user_id == ^trainer.id)

        trainer
        |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update!()

        log(scope, "trainer.removed", trainer, %{clients_moved: moved, moved_to: admin.id})
        %{clients_moved: moved}
      end)
    end
  end

  defp ensure_trainer(%User{role: "trainer"}), do: :ok
  defp ensure_trainer(_user), do: {:error, :forbidden}

  # Links the admin already has are dropped; the rest change hands.
  defp move_clients(trainer, admin) do
    moved =
      Repo.aggregate(
        from(tc in TrainerClient,
          where: tc.trainer_id == ^trainer.id and tc.status in ["active", "paused"]
        ),
        :count
      )

    already_admins =
      from tc in TrainerClient, where: tc.trainer_id == ^admin.id, select: tc.client_id

    Repo.delete_all(
      from tc in TrainerClient,
        where: tc.trainer_id == ^trainer.id and tc.client_id in subquery(already_admins)
    )

    Repo.update_all(
      from(tc in TrainerClient, where: tc.trainer_id == ^trainer.id),
      set: [trainer_id: admin.id]
    )

    moved
  end

  defp reassign_owned(trainer, admin) do
    for {schema, field} <- [
          {WorkoutPlan, :trainer_id},
          {NutritionPlan, :trainer_id},
          {Task, :trainer_id},
          {ProgressEntry, :trainer_id},
          {CalendarEvent, :user_id},
          {ClientWorkout, :assigned_by}
        ] do
      Repo.update_all(
        from(r in schema, where: field(r, ^field) == ^trainer.id),
        set: [{field, admin.id}]
      )
    end
  end

  defp log(%Scope{user: actor}, action, %User{} = subject, metadata) do
    Shared.create_activity_log(%{
      organization_id: actor.organization_id,
      user_id: actor.id,
      action: action,
      resource_type: "user",
      resource_id: subject.id,
      metadata: metadata
    })
  end

  # An unguessable hash: the trainer picks a real password from the emailed link.
  defp unusable_password_hash,
    do: Bcrypt.hash_pwd_salt(Base.url_encode64(:crypto.strong_rand_bytes(32)))
end
