defmodule AfyaFit.Payments.Daraja do
  @moduledoc """
  M-Pesa through Safaricom's Daraja API: an STK push asks the customer's phone
  for their PIN, and a query later confirms what happened.

  Configured under `config :afya_fit, AfyaFit.Payments.Daraja` (set from
  `DARAJA_*` environment variables in `runtime.exs`): `:base_url` (sandbox or
  production), `:consumer_key`, `:consumer_secret`, `:shortcode`, `:passkey`,
  `:transaction_type` (`CustomerPayBillOnline` or `CustomerBuyGoodsOnline`) and
  `:req_options` (tests plug a fake server in here).
  """

  @sandbox "https://sandbox.safaricom.co.ke"
  @token_key {__MODULE__, :token}

  @doc "Whether every credential is present."
  def enabled? do
    Enum.all?([:consumer_key, :consumer_secret, :shortcode, :passkey], &present?(config(&1)))
  end

  @doc """
  Normalises a Kenyan mobile number to the `2547XXXXXXXX` form Daraja wants.
  Accepts `0712345678`, `+254712345678`, `254712345678` and `712345678`.
  """
  @spec normalize_phone(term()) :: {:ok, String.t()} | :error
  def normalize_phone(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/[\s\-().]/, "")

    case Regex.run(~r/\A(?:\+?254|0)?([17]\d{8})\z/, digits) do
      [_, rest] -> {:ok, "254" <> rest}
      _ -> :error
    end
  end

  def normalize_phone(_phone), do: :error

  @doc """
  Sends the payment prompt to the customer's phone. `amount` is whole shillings.
  Returns the ids Daraja uses to find this request again.
  """
  @spec stk_push(map()) ::
          {:ok, %{checkout_request_id: String.t(), merchant_request_id: String.t()}}
          | {:error, term()}
  def stk_push(%{phone: phone, amount: amount, reference: reference, callback_url: callback_url}) do
    timestamp = timestamp()

    body = %{
      "BusinessShortCode" => config(:shortcode),
      "Password" => password(timestamp),
      "Timestamp" => timestamp,
      "TransactionType" => config(:transaction_type, "CustomerPayBillOnline"),
      "Amount" => amount,
      "PartyA" => phone,
      "PartyB" => config(:shortcode),
      "PhoneNumber" => phone,
      "CallBackURL" => callback_url,
      "AccountReference" => String.slice(reference, 0, 12),
      "TransactionDesc" => "Afya Fit plan"
    }

    with {:ok, %{"ResponseCode" => "0"} = response} <-
           post("/mpesa/stkpush/v1/processrequest", body) do
      {:ok,
       %{
         checkout_request_id: response["CheckoutRequestID"],
         merchant_request_id: response["MerchantRequestID"]
       }}
    else
      {:ok, response} -> {:error, response["errorMessage"] || response["ResponseDescription"]}
      {:error, _} = error -> error
    end
  end

  @doc """
  Asks Daraja what became of a push. `result_code` is `0` for paid, another
  number for a final failure, and `nil` while the customer has not answered.
  """
  @spec stk_query(String.t()) ::
          {:ok, %{result_code: integer() | nil, description: String.t() | nil}} | {:error, term()}
  def stk_query(checkout_request_id) do
    timestamp = timestamp()

    body = %{
      "BusinessShortCode" => config(:shortcode),
      "Password" => password(timestamp),
      "Timestamp" => timestamp,
      "CheckoutRequestID" => checkout_request_id
    }

    case post("/mpesa/stkpushquery/v1/query", body) do
      {:ok, %{"ResultCode" => code} = response} ->
        {:ok, %{result_code: to_int(code), description: response["ResultDesc"]}}

      # Daraja answers an unfinished request with an error body, not a result.
      {:ok, %{"errorCode" => _} = response} ->
        {:ok, %{result_code: nil, description: response["errorMessage"]}}

      {:ok, _other} ->
        {:ok, %{result_code: nil, description: nil}}

      {:error, _} = error ->
        error
    end
  end

  defp post(path, body) do
    with {:ok, token} <- access_token() do
      request(
        method: :post,
        url: base_url() <> path,
        json: body,
        auth: {:bearer, token}
      )
    end
  end

  defp request(options) do
    options = Keyword.merge([retry: false, receive_timeout: 15_000], options)

    case Req.request(Keyword.merge(options, config(:req_options, []))) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      # Daraja explains a refused request in the body.
      {:ok, %Req.Response{body: %{} = body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Tokens last an hour; keep one for 55 minutes.
  defp access_token do
    now = System.system_time(:second)

    case :persistent_term.get(@token_key, nil) do
      {token, expires_at} when expires_at > now ->
        {:ok, token}

      _ ->
        fetch_token(now)
    end
  end

  defp fetch_token(now) do
    result =
      request(
        method: :get,
        url: base_url() <> "/oauth/v1/generate",
        params: [grant_type: "client_credentials"],
        auth: {:basic, "#{config(:consumer_key)}:#{config(:consumer_secret)}"}
      )

    case result do
      {:ok, %{"access_token" => token}} ->
        :persistent_term.put(@token_key, {token, now + 55 * 60})
        {:ok, token}

      {:ok, _other} ->
        {:error, :no_access_token}

      {:error, _} = error ->
        error
    end
  end

  @doc false
  def forget_token, do: :persistent_term.erase(@token_key)

  defp password(timestamp),
    do: Base.encode64("#{config(:shortcode)}#{config(:passkey)}#{timestamp}")

  defp timestamp, do: Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")

  defp base_url, do: config(:base_url, @sandbox)

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp to_int(_value), do: nil

  defp present?(value), do: is_binary(value) and value != ""

  defp config(key, default \\ nil) do
    :afya_fit |> Application.get_env(__MODULE__, []) |> Keyword.get(key, default)
  end
end
