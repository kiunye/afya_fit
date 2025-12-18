defmodule AfyaFit.Nutrition.NutritionPlan do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "nutrition_plans" do
    belongs_to :organization, AfyaFit.Organizations.Organization
    belongs_to :trainer, AfyaFit.Accounts.User
    belongs_to :client, AfyaFit.Accounts.User

    field :name, :string
    field :description, :string
    field :daily_calories, :integer
    field :macros, :map
    field :start_date, :date
    field :end_date, :date
    field :is_template, :boolean, default: false
    field :deleted_at, :utc_datetime

    has_many :nutrition_meals, AfyaFit.Nutrition.NutritionMeal

    timestamps(type: :utc_datetime)
  end

  def changeset(nutrition_plan, attrs) do
    nutrition_plan
    |> cast(attrs, [
      :organization_id,
      :trainer_id,
      :client_id,
      :name,
      :description,
      :daily_calories,
      :macros,
      :start_date,
      :end_date,
      :is_template,
      :deleted_at
    ])
    |> validate_required([:organization_id, :trainer_id, :client_id, :name, :start_date])
  end
end
