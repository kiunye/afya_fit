defmodule AfyaFit.Nutrition do
  @moduledoc """
  The Nutrition context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Nutrition.{NutritionMeal, NutritionPlan}
  alias AfyaFit.Repo

  def list_nutrition_plans do
    Repo.all(NutritionPlan)
  end

  @doc """
  Lists the nutrition plans the scope's user may read: trainers see their own,
  their linked clients' and the organization's templates; clients see plans
  assigned to them; organization admins see the whole organization.
  """
  def list_nutrition_plans_for(%Scope{user: user} = scope) do
    in_org = from p in NutritionPlan, where: p.organization_id == ^user.organization_id

    case Scope.role(scope) do
      :admin ->
        Repo.all(NutritionPlan)

      :org_admin ->
        Repo.all(in_org)

      :trainer ->
        client_ids = MapSet.to_list(scope.client_ids)

        Repo.all(
          from p in in_org,
            where: p.trainer_id == ^user.id or p.is_template or p.client_id in ^client_ids
        )

      :client ->
        Repo.all(from p in in_org, where: p.client_id == ^user.id)

      _ ->
        []
    end
  end

  @doc "Lists the plans assigned to `client`."
  def list_client_nutrition_plans(%{id: client_id, organization_id: organization_id}) do
    Repo.all(
      from p in NutritionPlan,
        where: p.organization_id == ^organization_id and p.client_id == ^client_id
    )
  end

  def get_nutrition_plan!(id), do: Repo.get!(NutritionPlan, id)

  @doc "Gets a nutrition plan with its client, or `nil`."
  def get_nutrition_plan(id) do
    NutritionPlan |> Repo.get(id) |> Repo.preload(:client)
  end

  def create_nutrition_plan(attrs \\ %{}) do
    %NutritionPlan{}
    |> NutritionPlan.changeset(attrs)
    |> Repo.insert()
  end

  def update_nutrition_plan(%NutritionPlan{} = nutrition_plan, attrs) do
    nutrition_plan
    |> NutritionPlan.changeset(attrs)
    |> Repo.update()
  end

  def delete_nutrition_plan(%NutritionPlan{} = nutrition_plan) do
    Repo.delete(nutrition_plan)
  end

  def change_nutrition_plan(%NutritionPlan{} = nutrition_plan, attrs \\ %{}) do
    NutritionPlan.changeset(nutrition_plan, attrs)
  end

  def create_nutrition_meal(attrs \\ %{}) do
    %NutritionMeal{}
    |> NutritionMeal.changeset(attrs)
    |> Repo.insert()
  end
end
