defmodule AfyaFit.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string
    field :role, :string
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :avatar_url, :string
    # nil until the user or their browser says; `AfyaFit.Timezone.zone/1` shows UTC meanwhile
    field :timezone, :string
    field :email_verified, :boolean, default: false
    field :email_verified_at, :utc_datetime
    field :last_login_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :organization, AfyaFit.Organizations.Organization
    has_many :tokens, AfyaFit.Accounts.UserToken

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: binary(),
          email: String.t(),
          password: String.t() | nil,
          password_hash: String.t(),
          role: String.t(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          phone: String.t() | nil,
          avatar_url: String.t() | nil,
          timezone: String.t() | nil,
          email_verified: boolean(),
          email_verified_at: DateTime.t() | nil,
          last_login_at: DateTime.t() | nil,
          deleted_at: DateTime.t() | nil,
          organization_id: binary(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords
  may also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :email,
      :password,
      :role,
      :first_name,
      :last_name,
      :phone,
      :avatar_url,
      :timezone,
      :organization_id
    ])
    |> validate_email()
    |> validate_password(opts)
    |> validate_required([:email, :role, :first_name, :last_name, :organization_id])
    |> validate_inclusion(:role, ["trainer", "client", "admin"])
    |> validate_timezone()
  end

  @doc """
  The role API clients built before organization admins understand: an
  `org_admin` is a trainer who owns the organization. Newer clients read
  `account_role` (the real role) and `permissions` instead.
  """
  def legacy_role(%__MODULE__{role: "org_admin"}), do: "trainer"
  def legacy_role(%__MODULE__{role: role}), do: role

  @doc """
  A changeset for editing someone's profile details. It casts only the fields a
  trainer may change on a client; role, organization and credentials are never
  touched.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :first_name, :last_name, :phone, :avatar_url, :timezone])
    |> validate_required([:email, :first_name, :last_name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, AfyaFit.Repo)
    |> unique_constraint(:email)
    |> validate_timezone()
  end

  @doc "A changeset that changes only the user's time zone."
  def timezone_changeset(user, attrs) do
    user
    |> cast(attrs, [:timezone])
    |> validate_required([:timezone])
    |> validate_timezone()
  end

  defp validate_timezone(changeset) do
    validate_change(changeset, :timezone, fn :timezone, zone ->
      if AfyaFit.Timezone.valid?(zone), do: [], else: [timezone: "is not a time zone we know"]
    end)
  end

  @doc """
  A changeset for adding a trainer to an organization. The role, organization
  and an unusable password are set by the caller; the trainer chooses a
  password from the emailed link.
  """
  def trainer_invite_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :first_name, :last_name])
    |> validate_required([:email, :first_name, :last_name])
    |> validate_format(:email, ~r/^[^s]+@[^s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, AfyaFit.Repo)
    |> unique_constraint(:email)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, AfyaFit.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `email_verified` to true.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, email_verified: true, email_verified_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%AfyaFit.Accounts.User{password_hash: password_hash}, password)
      when is_binary(password_hash) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, password_hash)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :password,
      :password_hash,
      :role,
      :first_name,
      :last_name,
      :phone,
      :avatar_url,
      :timezone,
      :organization_id
    ])
    |> validate_required([:email, :role, :first_name, :last_name, :organization_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, AfyaFit.Repo)
    |> unique_constraint(:email)
    |> validate_inclusion(:role, ["trainer", "client", "admin", "org_admin"])
  end
end
