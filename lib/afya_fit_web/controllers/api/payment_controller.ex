defmodule AfyaFitWeb.API.PaymentController do
  @dialyzer {:nowarn_function, initialize: 2}
  use AfyaFitWeb, :controller

  alias AfyaFit.Payments.PaystackClient

  # Authentication is handled in router pipeline

  plug AfyaFitWeb.API.AuthorizePlug, resource: :subscription, default: :manage

  action_fallback AfyaFitWeb.API.FallbackController

  def initialize(conn, %{"payment" => payment_params}) do
    current_user = conn.assigns.current_user

    email = Map.get(payment_params, "email", current_user.email)
    amount = Map.get(payment_params, "amount")
    reference = PaystackClient.generate_reference()

    metadata = %{
      organization_id: current_user.organization_id,
      user_id: current_user.id
    }

    case PaystackClient.initialize_transaction(email, amount, reference, metadata) do
      {:ok, %Paystack.Response{success: true, data: data}} ->
        json(conn, %{
          data: %{
            authorization_url: data["authorization_url"],
            access_code: data["access_code"],
            reference: data["reference"]
          }
        })

      {:ok, %Paystack.Response{success: false, message: message, status_code: status_code}} ->
        http_status = if is_integer(status_code), do: status_code, else: :unprocessable_entity

        conn
        |> put_status(http_status)
        |> json(%{error: "Failed to initialize payment", message: message})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Payment initialization failed", details: inspect(reason)})
    end
  end
end
