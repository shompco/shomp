defmodule Shomp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :name, :string
    field :bio, :string
    field :location, :string
    field :website, :string
    field :verified, :boolean, default: false
    field :role, :string, default: "user"
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :trial_ends_at, :utc_datetime
    
    belongs_to :tier, Shomp.Accounts.Tier, type: :binary_id
    has_many :stores, Shomp.Stores.Store
    has_many :payments, Shomp.Payments.Payment
    has_many :downloads, Shomp.Downloads.Download
    has_many :carts, Shomp.Carts.Cart
    has_many :requests, Shomp.FeatureRequests.Request

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

  It requires email and name to be present. Password is optional for magic link users.
  Users can set passwords later and use both authentication methods.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :name, :username])
    |> validate_email(opts)
    |> validate_username(opts)
    |> validate_required([:name, :username])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:username, min: 3, max: 30)
    |> maybe_validate_password(opts)
  end

  @doc """
  A user changeset for password-based registration.

  It requires email, password, and name to be present.
  """
  def password_registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :name, :username])
    |> validate_email(opts)
    |> validate_username(opts)
    |> validate_password(opts)
    |> validate_required([:name, :username])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:username, min: 3, max: 30)
  end

  @doc """
  A user changeset for adding/updating a password.

  Can be used to add a password to a magic link user or update existing password.
  """
  def add_password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_password(opts)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  @doc """
  A user changeset for changing the username.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the username, useful when displaying live validations.
      Defaults to `true`.
  """
  def username_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username])
    |> validate_username(opts)
  end

  @doc """
  A user changeset for updating profile information.
  """
  def profile_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :name, :bio, :location, :website])
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:bio, max: 500)
    |> validate_length(:location, max: 100)
    |> validate_length(:website, max: 200)
    |> validate_format(:website, ~r/^https?:\/\/.+/, message: "must be a valid URL starting with http:// or https://")
    |> validate_username(opts)
    |> maybe_validate_website()
  end

  defp maybe_validate_website(changeset) do
    website = get_change(changeset, :website)
    
    if website && website != "" do
      validate_format(changeset, :website, ~r/^https?:\/\/.+/, message: "must be a valid URL starting with http:// or https://")
    else
      changeset
    end
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Shomp.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  defp validate_username(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:username])
      |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
        message: "can only contain letters, numbers, underscores, and hyphens"
      )
      |> validate_length(:username, min: 3, max: 30)
      |> validate_username_store_conflict()

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:username, Shomp.Repo)
      |> unique_constraint(:username)
    else
      changeset
    end
  end

  defp validate_username_store_conflict(changeset) do
    username = get_change(changeset, :username) || get_field(changeset, :username)
    
    if username do
      # Convert username to store slug format for comparison
      potential_store_slug = username
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9-]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")
      
      # Check if this would conflict with an existing store slug
      case Shomp.Repo.get_by(Shomp.Stores.Store, slug: potential_store_slug) do
        nil -> changeset
        _store -> 
          add_error(changeset, :username, "username conflicts with existing store name '#{potential_store_slug}'. Please choose a different username.")
      end
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

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

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_password(changeset, opts) do
    password = get_change(changeset, :password)
    
    if password do
      validate_password(changeset, opts)
    else
      changeset
    end
  end

  @doc """
  A user changeset for updating tier information.
  """
  def tier_changeset(user, attrs) do
    user
    |> cast(attrs, [:tier_id, :trial_ends_at])
    |> validate_required([:tier_id])
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Shomp.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
