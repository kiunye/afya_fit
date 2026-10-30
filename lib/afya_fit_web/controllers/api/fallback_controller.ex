defmodule AfyaFitWeb.API.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use AfyaFitWeb, :controller

  alias AfyaFit.PlanBlocks

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(AfyaFitWeb.API.ErrorView)
    |> render(:"422", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(AfyaFitWeb.API.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(AfyaFitWeb.API.ErrorView)
    |> render(:"403")
  end

  def call(conn, {:error, :archived}) do
    conn
    |> put_status(:forbidden)
    |> json(%{
      error: "archived",
      message: "Your coaching has ended, so your data is read-only."
    })
  end

  def call(conn, {:error, {:upgrade_required, details}} = error) do
    PlanBlocks.record(conn.assigns[:current_scope], error)

    conn
    |> put_status(:payment_required)
    |> put_view(AfyaFitWeb.API.ErrorView)
    |> render(:"402", error: "upgrade_required", details: details)
  end

  def call(conn, {:error, {:subscription_inactive, status}} = error) do
    PlanBlocks.record(conn.assigns[:current_scope], error)

    conn
    |> put_status(:payment_required)
    |> put_view(AfyaFitWeb.API.ErrorView)
    |> render(:"402", error: "subscription_inactive", details: %{status: status})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(AfyaFitWeb.API.ErrorView)
    |> render(:"401")
  end
end
