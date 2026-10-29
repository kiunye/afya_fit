defmodule AfyaFitWeb.API.NutritionPlanController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Authorization, Clients, Nutrition}
  alias AfyaFit.Authorization.Scope

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, _params) do
    scope = conn.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :list, :nutrition_plan) do
      render(conn, :index, nutrition_plans: Nutrition.list_nutrition_plans_for(scope))
    end
  end

  def create(conn, %{"nutrition_plan" => nutrition_plan_params}) do
    scope = conn.assigns.current_scope

    attrs =
      nutrition_plan_params
      |> Map.put("organization_id", scope.user.organization_id)
      |> Map.put("trainer_id", scope.user.id)

    with :ok <- Authorization.authorize(scope, :create, :nutrition_plan),
         :ok <- authorize_client(scope, attrs["client_id"]),
         {:ok, nutrition_plan} <- Nutrition.create_nutrition_plan(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, nutrition_plan: nutrition_plan)
    end
  end

  def show(conn, %{"id" => id}) do
    nutrition_plan = Nutrition.get_nutrition_plan!(id)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, :read, nutrition_plan) do
      render(conn, :show, nutrition_plan: nutrition_plan)
    end
  end

  def update(conn, %{"id" => id, "nutrition_plan" => nutrition_plan_params}) do
    scope = conn.assigns.current_scope
    nutrition_plan = Nutrition.get_nutrition_plan!(id)

    with :ok <- Authorization.authorize(scope, :update, nutrition_plan),
         :ok <- authorize_client(scope, nutrition_plan_params["client_id"]),
         {:ok, nutrition_plan} <-
           Nutrition.update_nutrition_plan(nutrition_plan, nutrition_plan_params) do
      render(conn, :show, nutrition_plan: nutrition_plan)
    end
  end

  def delete(conn, %{"id" => id}) do
    nutrition_plan = Nutrition.get_nutrition_plan!(id)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, :delete, nutrition_plan),
         {:ok, _nutrition_plan} <- Nutrition.delete_nutrition_plan(nutrition_plan) do
      send_resp(conn, :no_content, "")
    end
  end

  def client_nutrition(conn, %{"client_id" => client_id}) do
    scope = conn.assigns.current_scope

    with {:ok, client} <- Clients.fetch_for(scope, :read, client_id) do
      render(conn, :index, nutrition_plans: Nutrition.list_client_nutrition_plans(client))
    end
  end

  # A plan may only be assigned to a client the requester coaches.
  defp authorize_client(_scope, nil), do: :ok

  defp authorize_client(scope, client_id) do
    if Scope.manages_client?(scope, client_id), do: :ok, else: {:error, :forbidden}
  end
end
