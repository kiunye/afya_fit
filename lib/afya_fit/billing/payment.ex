defmodule AfyaFit.Billing.Payment do
  @moduledoc """
  One attempt to pay for a plan, by card or M-Pesa. `reference` is ours and
  unique; `provider_reference` is the provider's (the M-Pesa checkout request).
  A payment settles at most once, so repeated webhooks are harmless.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "payments" do
    belongs_to :organization, AfyaFit.Organizations.Organization
    belongs_to :user, AfyaFit.Accounts.User

    field :provider, :string
    field :plan_type, :string
    field :amount, :decimal
    field :currency, :string, default: "KES"
    field :status, :string, default: "pending"
    field :reference, :string
    field :provider_reference, :string
    field :phone, :string
    field :callback_token, :string
    field :receipt, :string
    field :failure_reason, :string
    field :provider_payload, :map, default: %{}
    field :paid_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @providers ~w(paystack daraja)
  @statuses ~w(pending succeeded failed expired)

  def providers, do: @providers
  def statuses, do: @statuses

  @doc "A new pending payment. Everything here is set by the server, never cast from a request."
  def create_changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :organization_id,
      :user_id,
      :provider,
      :plan_type,
      :amount,
      :currency,
      :reference,
      :phone,
      :callback_token
    ])
    |> validate_required([:organization_id, :provider, :plan_type, :amount, :reference])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:plan_type, ["pro", "enterprise"])
    |> validate_number(:amount, greater_than: 0)
    |> unique_constraint(:reference)
    |> unique_constraint(:callback_token)
  end

  @doc "Records how the provider answered, and the new status."
  def update_changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :status,
      :provider_reference,
      :receipt,
      :failure_reason,
      :provider_payload,
      :paid_at
    ])
    |> validate_inclusion(:status, @statuses)
  end
end
