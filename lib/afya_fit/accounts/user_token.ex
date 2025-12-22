defmodule AfyaFit.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query
  alias AfyaFit.Accounts.UserToken

  @moduledoc false

  @session_validity_in_days 60
  @email_validity_in_days 1

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, AfyaFit.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user
  sessions to be expired. The token generated can only be
  used once, as it is deleted after being used.
  """
  @spec build_session_token(AfyaFit.Accounts.User.t()) :: {String.t(), %UserToken{}}
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(32)
    {Base.url_encode64(token, padding: false), %UserToken{
        token: token,
        context: "session",
        user_id: user.id
      }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        query =
          from token in token_query(decoded_token, "session"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(@session_validity_in_days, "day"),
            select: user

        {:ok, query}

      :error ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Builds a token and its hash to be delivered to the user's email.

  The non-hashed token is sent to the user email while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the user changes
  their email in the system, the tokens sent to the previous email are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.
  """
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(32)
    hashed_token = :crypto.hash(:sha256, token)

    {Base.url_encode64(token, padding: false), %UserToken{
        token: hashed_token,
        context: context,
        sent_to: sent_to,
        user_id: user.id
      }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  This is used to validate a token sent to the user email to verify
  their account. The token is valid if it matches one in the database
  and the user it belongs to hasn't changed their email.

  The token has a validity period specified by @email_validity_in_days.
  """
  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(:sha256, decoded_token)
        days = days_for_context(context)

        query =
          from token in token_query(hashed_token, context),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The given token is valid if it matches its hashed value in the database
  and the user email has not changed. This function also checks if the token
  is being used within a certain period, depending on the context. The default
  contexts supported by this function are either "confirm", for account
  confirmation emails, and "reset_password", for resetting the password.

  For example, in the "reset_password" context, the token is valid for 1 day.
  """
  def verify_change_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(:sha256, decoded_token)

        query =
          from token in token_query(hashed_token, context),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(@email_validity_in_days, "day"),
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  defp token_query(token, context) when is_binary(token) or is_atom(token) do
    from UserToken, where: [token: ^token, context: ^context]
  end

  @doc """
  Returns a query for all tokens for a given user.
  Used when deleting all tokens for a user (e.g., on password change).
  """
  def token_and_context_query(user_id, :all) do
    from UserToken, where: [user_id: ^user_id]
  end

  defp days_for_context("confirm"), do: @email_validity_in_days
  defp days_for_context("reset_password"), do: @email_validity_in_days
end


