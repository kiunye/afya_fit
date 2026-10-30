defmodule AfyaFit.Billing.Plans do
  @moduledoc """
  What the paid plans cost. One source for the prices, so checkout, invoices and
  the platform's income figure agree. Each payment buys one 30-day period;
  paying again before it ends extends it.

  Prices are whole Kenyan shillings a month and can be overridden with
  `config :afya_fit, :plan_prices, %{"pro" => 1500}` (or the `PLAN_PRICE_PRO` and
  `PLAN_PRICE_ENTERPRISE` environment variables); plans left out keep their default.
  """

  @default_prices %{"pro" => 1500, "enterprise" => 5000}
  @currency "KES"
  @period_days 30

  def currency, do: @currency
  def period_days, do: @period_days

  @doc "The plans that can be paid for, cheapest first."
  def paid_plans, do: prices() |> Enum.sort_by(&elem(&1, 1)) |> Enum.map(&elem(&1, 0))

  @doc "Whole shillings for one period, or `nil` for a plan that is not for sale."
  def price(plan), do: Map.get(prices(), plan)

  def paid?(plan), do: Map.has_key?(prices(), plan)

  @doc "`1500` as `KES 1,500`."
  def format(amount) do
    whole = amount |> Decimal.new() |> Decimal.round(0) |> Decimal.to_integer()

    digits =
      whole
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
      |> String.reverse()

    "#{@currency} #{digits}"
  end

  defp prices, do: Map.merge(@default_prices, Application.get_env(:afya_fit, :plan_prices, %{}))
end
