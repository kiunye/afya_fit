defmodule AfyaFitWeb.API.NutritionPlanController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Clients, Nutrition}

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    nutrition_plans =
      Nutrition.list_nutrition_plans()
      |> Enum.filter(fn plan ->
        plan.organization_id == current_user.organization_id &&
          (plan.trainer_id == current_user.id || plan.client_id == current_user.id ||
             current_user.role == "admin")
      end)

    render(conn, :index, nutrition_plans: nutrition_plans)
  end

  def create(conn, %{"nutrition_plan" => nutrition_plan_params}) do
    current_user = conn.assigns.current_user

    attrs =
      nutrition_plan_params
      |> Map.put("organization_id", current_user.organization_id)
      |> Map.put("trainer_id", current_user.id)

    # Verify client access if client_id is provided
    if client_id = Map.get(attrs, "client_id") do
      unless Clients.trainer_has_client?(current_user.id, client_id) do
        conn
        |> put_status(:forbidden)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"403")
        |> halt()
      end
    end

    case Nutrition.create_nutrition_plan(attrs) do
      {:ok, nutrition_plan} ->
        conn
        |> put_status(:created)
        |> render(:show, nutrition_plan: nutrition_plan)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    nutrition_plan = Nutrition.get_nutrition_plan!(id)

    # Verify access
    if nutrition_plan.organization_id == current_user.organization_id &&
         (nutrition_plan.trainer_id == current_user.id ||
            nutrition_plan.client_id == current_user.id || current_user.role == "admin") do
      render(conn, :show, nutrition_plan: nutrition_plan)
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def update(conn, %{"id" => id, "nutrition_plan" => nutrition_plan_params}) do
    current_user = conn.assigns.current_user
    nutrition_plan = Nutrition.get_nutrition_plan!(id)

    # Verify ownership
    if nutrition_plan.trainer_id == current_user.id || current_user.role == "admin" do
      case Nutrition.update_nutrition_plan(nutrition_plan, nutrition_plan_params) do
        {:ok, nutrition_plan} ->
          render(conn, :show, nutrition_plan: nutrition_plan)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(AfyaFitWeb.API.ErrorView)
          |> render(:"422", changeset: changeset)
      end
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    nutrition_plan = Nutrition.get_nutrition_plan!(id)

    # Verify ownership
    if nutrition_plan.trainer_id == current_user.id || current_user.role == "admin" do
      Nutrition.delete_nutrition_plan(nutrition_plan)
      send_resp(conn, :no_content, "")
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def client_nutrition(conn, %{"client_id" => client_id}) do
    current_user = conn.assigns.current_user

    # Verify client access
    if current_user.role == "trainer" do
      Clients.get_client!(current_user, client_id)
    end

    nutrition_plans =
      Nutrition.list_nutrition_plans()
      |> Enum.filter(fn plan ->
        plan.organization_id == current_user.organization_id && plan.client_id == client_id
      end)

    render(conn, :index, nutrition_plans: nutrition_plans)
  end
end
