defmodule AfyaFit.Billing.Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "invoices" do
    belongs_to :subscription, AfyaFit.Billing.Subscription

    field :invoice_number, :string
    field :amount, :decimal
    field :currency, :string, default: "KES"
    field :status, :string, default: "pending"
    field :paystack_invoice_code, :string
    field :due_date, :date
    field :paid_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [
      :subscription_id,
      :invoice_number,
      :amount,
      :currency,
      :status,
      :paystack_invoice_code,
      :due_date,
      :paid_at
    ])
    |> validate_required([:subscription_id, :invoice_number, :amount, :due_date, :status])
    |> validate_inclusion(:status, ["pending", "paid", "failed", "refunded"])
    |> unique_constraint(:invoice_number)
  end
end
