defmodule Shomp.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo

  alias Shomp.Accounts.{User, UserToken, UserNotifier, Tier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by ID.

  ## Examples

      iex> get_user_by_id(1)
      %User{}

      iex> get_user_by_id(999)
      nil

  """
  def get_user_by_id(id) do
    Repo.get(User, id)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Authenticates a user by email and password.

  ## Examples

      iex> authenticate("foo@example.com", "correct_password")
      {:ok, %User{}}

      iex> authenticate("foo@example.com", "invalid_password")
      {:error, :invalid_credentials}

      iex> authenticate("unknown@example.com", "password")
      {:error, :invalid_credentials}

  """
  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    case get_user_by_email_and_password(email, password) do
      %User{} = user -> {:ok, user}
      nil -> {:error, :invalid_credentials}
    end
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by immutable_id.

  ## Examples

      iex> get_user_by_immutable_id("user_123")
      %User{}

      iex> get_user_by_immutable_id("unknown")
      nil

  """
  def get_user_by_immutable_id(immutable_id) when is_binary(immutable_id) do
    Repo.get_by(User, id: immutable_id)
  end

  @doc """
  Gets a user by username.

  ## Examples

      iex> get_user_by_username("johndoe")
      %User{}

      iex> get_user_by_username("unknown")
      nil

  """
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Gets a user by username with their default store and products preloaded.
  """
  def get_user_with_store_and_products(username) do
    from(u in User, where: u.username == ^username)
    |> Repo.one()
    |> case do
      nil -> nil
      user ->
        store = Shomp.Stores.get_user_default_store(user)
        products = if store, do: Shomp.Products.list_products_by_store(store.store_id), else: []
        Map.put(user, :products, products)
    end
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{email: "user@example.com", password: "password123", name: "John Doe"})
      {:ok, %User{}}

      iex> register_user(%{email: "user@example.com", name: "John Doe"})
      {:ok, %User{}}

      iex> register_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    default_tier = get_default_tier()

    case %User{}
         |> User.registration_changeset(attrs)
         |> Ecto.Changeset.put_change(:tier_id, default_tier.id)
         |> Repo.insert() do
      {:ok, user} = result ->
        # Auto-create default store for new user
        Shomp.Stores.ensure_default_store(user)

        # Broadcast to admin dashboard
        Phoenix.PubSub.broadcast(Shomp.PubSub, "admin:users", %{
          event: "user_registered",
          payload: user
        })
        result
      error -> error
    end
  end

  @doc """
  Adds or updates a password for an existing user.

  ## Examples

      iex> add_user_password(user, %{password: "new_password123"})
      {:ok, %User{}}

  """
  def add_user_password(%User{} = user, attrs) do
    user
    |> User.add_password_changeset(attrs)
    |> Repo.update()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Shomp.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user username.

  ## Examples

      iex> change_user_username(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_username(user, attrs \\ %{}, opts \\ []) do
    User.username_changeset(user, attrs, opts)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for user registration.

  ## Examples

      iex> change_user_registration(%User{})
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, validate_unique: false)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Shomp.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  @doc """
  Updates the user username.

  Returns a tuple with the updated user.

  ## Examples

      iex> update_user_username(user, %{username: "newusername"})
      {:ok, %User{}}

      iex> update_user_username(user, %{username: "too"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_username(user, attrs) do
    user
    |> User.username_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the user profile information.

  Returns a tuple with the updated user.

  ## Examples

      iex> update_user(user, %{username: "newusername", bio: "My bio"})
      {:ok, %User{}}

      iex> update_user(user, %{username: "too"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  Users can use magic links regardless of whether they have a password set.
  This allows flexible authentication - users can choose their preferred method.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     The user gets confirmed and logged in, maintaining security best practices.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Allow magic links for all users, including those with passwords
      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    require Logger
    Logger.info("🔑 LOGIN DEBUG: Building token for user: #{user.email}")
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Logger.info("💾 LOGIN DEBUG: Inserting token into database...")
    Repo.insert!(user_token)
    Logger.info("📤 LOGIN DEBUG: Calling UserNotifier.deliver_login_instructions...")
    result = UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
    Logger.info("📤 LOGIN DEBUG: UserNotifier result: #{inspect(result)}")
    result
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  ## Tier management

  @doc """
  Gets a single tier by ID.
  """
  def get_tier!(id), do: Repo.get!(Tier, id)

  @doc """
  Gets a tier by slug.
  """
  def get_tier_by_slug(slug), do: Repo.get_by(Tier, slug: slug)

  @doc """
  Lists all active tiers ordered by sort_order.
  """
  def list_active_tiers do
    Tier
    |> where([t], t.is_active == true)
    |> order_by([t], t.sort_order)
    |> Repo.all()
  end

  @doc """
  Gets the default free tier.
  """
  def get_default_tier, do: get_tier_by_slug("free")

  @doc """
  Assigns the default tier to users who don't have one.
  """
  def assign_default_tier_to_user(user) do
    if !user.tier_id do
      default_tier = get_default_tier()
      upgrade_user_tier(user, default_tier)
    else
      {:ok, user}
    end
  end

  @doc """
  Upgrades a user to a new tier.
  """
  def upgrade_user_tier(user, tier) do
    user
    |> User.tier_changeset(%{tier_id: tier.id})
    |> Repo.update()
  end

  @doc """
  Checks user limits based on their current tier.
  """
  def check_user_limits(user) do
    user = Repo.preload(user, :tier)

    %{
      store_count: count_user_stores(user.id),
      store_limit: user.tier.store_limit,
      can_create_store: count_user_stores(user.id) < user.tier.store_limit,
      product_count: count_user_products(user.id),
      product_limit: user.tier.product_limit_per_store
    }
  end

  defp count_user_stores(user_id) do
    Shomp.Stores.count_user_stores(user_id)
  end

  defp count_user_products(user_id) do
    Shomp.Products.count_user_products(user_id)
  end
end
