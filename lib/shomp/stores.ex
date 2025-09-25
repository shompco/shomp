defmodule Shomp.Stores do
  @moduledoc """
  The Stores context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Stores.Store
  alias Shomp.Stores.StoreKYCContext

  @doc """
  Returns the list of stores.
  """
  def list_stores do
    Repo.all(Store)
  end

  @doc """
  Returns the list of stores with user associations loaded.
  """
  def list_stores_with_users do
    Store
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Returns the list of stores with user association loaded (singular).
  """
  def list_stores_with_user do
    Store
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Returns the list of stores with user and products associations loaded.
  """
  def list_stores_with_users_and_products do
    Store
    |> Repo.all()
    |> Repo.preload([:user, :products])
  end

  @doc """
  Gets a single store.

  Raises `Ecto.NoResultsError` if the Store does not exist.

  ## Examples

      iex> get_store!(123)
      %Store{}

      iex> get_store!(456)
      ** (Ecto.NoResultsError)

  """
  def get_store!(id), do: Repo.get!(Store, id)

  @doc """
  Gets a single store with user association loaded.

  Raises `Ecto.NoResultsError` if the Store does not exist.

  ## Examples

      iex> get_store_with_user!(123)
      %Store{user: %User{}}

      iex> get_store_with_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_store_with_user!(id) do
    Store
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

  @doc """
  Gets a store by slug.

  ## Examples

      iex> get_store_by_slug("my-store")
      %Store{}

      iex> get_store_by_slug("unknown-store")
      nil

  """
  def get_store_by_slug(slug) do
    Repo.get_by(Store, slug: slug)
  end

  @doc """
  Gets a store by slug with user association loaded.

  ## Examples

      iex> get_store_by_slug_with_user("my-store")
      %Store{user: %User{}}

      iex> get_store_by_slug_with_user("unknown-store")
      nil

  """
  def get_store_by_slug_with_user(slug) do
    Store
    |> Repo.get_by(slug: slug)
    |> case do
      nil -> nil
      store -> Repo.preload(store, :user)
    end
  end

  @doc """
  Gets stores by user ID.

  ## Examples

      iex> get_stores_by_user(123)
      [%Store{}, ...]

  """
  def get_stores_by_user(user_id) do
    Repo.all(from s in Store, where: s.user_id == ^user_id)
  end

  @doc """
  Gets a store by its immutable store_id.

  ## Examples

      iex> get_store_by_store_id("uuid-here")
      %Store{}

      iex> get_store_by_store_id("unknown-uuid")
      nil

  """
  def get_store_by_store_id(store_id) do
    Repo.get_by(Store, store_id: store_id)
  end

  @doc """
  Gets a single store by its immutable store_id.

  Raises `Ecto.NoResultsError` if the Store does not exist.
  """
  def get_store_by_store_id!(store_id) do
    Repo.get_by!(Store, store_id: store_id)
  end

  @doc """
  Gets a store by its immutable store_id with user association loaded.

  ## Examples

      iex> get_store_by_store_id_with_user("uuid-here")
      %Store{user: %User{}}

      iex> get_store_by_store_id_with_user("unknown-uuid")
      nil

  """
  def get_store_by_store_id_with_user(store_id) do
    Store
    |> Repo.get_by(store_id: store_id)
    |> case do
      nil -> nil
      store -> Repo.preload(store, :user)
    end
  end

  @doc """
  Creates a store.

  ## Examples

      iex> create_store(%{field: value})
      {:ok, %Store{}}

      iex> create_store(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_store(attrs \\ %{}) do
    IO.puts("=== CREATING STORE ===")
    IO.puts("Store attributes: #{inspect(attrs)}")

    changeset = %Store{}
    |> Store.create_changeset(attrs)

    IO.puts("Changeset valid?: #{changeset.valid?}")
    IO.puts("Changeset errors: #{inspect(changeset.errors)}")
    IO.puts("Changeset changes: #{inspect(changeset.changes)}")

    case changeset |> Repo.insert() do
      {:ok, store} = result ->
        IO.puts("✅ Store created successfully: #{store.store_id}")
        IO.puts("Store user ID: #{store.user_id}")
        IO.puts("Store name: #{store.name}")
        IO.puts("Store slug: #{store.slug}")
        IO.puts("Store is_default: #{store.is_default}")

        # Always create Stripe Connected Account when store is created
        # This ensures every store has a Stripe account (even if restricted)
        case create_stripe_connected_account_for_new_store(store) do
          {:ok, stripe_account_id} ->
            IO.puts("✅ Successfully created/linked Stripe account #{stripe_account_id} for store #{store.store_id}")
          {:error, reason} ->
            IO.puts("❌ CRITICAL: Failed to create Stripe account for store #{store.store_id}: #{inspect(reason)}")
            # Log this as a critical error since every store needs a Stripe account
            # The store was created but without Stripe integration
        end

        # Broadcast to admin dashboard
        Phoenix.PubSub.broadcast(Shomp.PubSub, "admin:stores", %{
          event: "store_created",
          payload: store
        })
        result
      {:error, changeset} ->
        IO.puts("❌ Store creation failed!")
        IO.puts("Changeset errors: #{inspect(changeset.errors)}")
        IO.puts("Changeset data: #{inspect(changeset.data)}")
        {:error, changeset}
    end
  end

  @doc """
  Creates a store and raises on error.

  ## Examples

      iex> create_store!(%{field: value})
      %Store{}

      iex> create_store!(%{field: bad_value})
      ** (Ecto.InvalidChangesetError)

  """
  def create_store!(attrs \\ %{}) do
    case create_store(attrs) do
      {:ok, store} -> store
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Updates a store.

  ## Examples

      iex> update_store(store, %{field: new_value})
      {:ok, %Store{}}

      iex> update_store(store, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_store(%Store{} = store, attrs) do
    store
    |> Store.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a store.

  ## Examples

      iex> delete_store(store)
      {:ok, %Store{}}

      iex> delete_store(store)
      {:error, %Ecto.Changeset{}}

  """
  def delete_store(%Store{} = store) do
    Repo.delete(store)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking store changes.

  ## Examples

      iex> change_store(store)
      %Ecto.Changeset{data: %Store{}}

  """
  def change_store(%Store{} = store, attrs \\ %{}) do
    Store.changeset(store, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for creating a store.

  ## Examples

      iex> change_store_creation(store)
      %Ecto.Changeset{data: %Store{}}

  """
  def change_store_creation(%Store{} = store, attrs \\ %{}) do
    Store.create_changeset(store, attrs)
  end

  @doc """
  Counts the number of stores for a specific user.
  """
  def count_user_stores(user_id) do
    Store
    |> where([s], s.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Lists stores by user ID.
  """
  def list_stores_by_user(user_id) do
    Store
    |> where([s], s.user_id == ^user_id)
    |> Repo.all()
  end

  # Public functions

  @doc """
  Gets the Stripe Connected Account for a store.
  Returns the user's existing Stripe account (created at store creation).
  """
  def ensure_stripe_connected_account(store_id) do
    store = get_store_by_store_id(store_id)
    if store do
      get_stripe_connected_account(store)
    else
      {:error, :store_not_found}
    end
  end

  @doc """
  Gets or creates the default store for a user.
  This is the main function to use instead of managing multiple stores.
  """
  def get_user_default_store(user) do
    IO.puts("=== GET_USER_DEFAULT_STORE DEBUG ===")
    IO.puts("User ID: #{user.id}")
    IO.puts("User username: #{user.username}")

    case get_default_store_by_user(user.id) do
      nil ->
        IO.puts("No existing default store found, creating new one...")
        case ensure_default_store(user) do
          {:ok, store} ->
            IO.puts("✅ Successfully created/retrieved default store: #{store.store_id}")
            IO.puts("Store name: #{store.name}")
            IO.puts("Store slug: #{store.slug}")
            IO.puts("Store is_default: #{store.is_default}")
            store
          {:error, reason} ->
            IO.puts("❌ Failed to create default store: #{inspect(reason)}")
            nil
        end
      store ->
        IO.puts("✅ Found existing default store: #{store.store_id}")
        IO.puts("Store name: #{store.name}")
        IO.puts("Store slug: #{store.slug}")
        IO.puts("Store is_default: #{store.is_default}")
        store
    end
  end

  @doc """
  Gets a store by username (for public store pages).
  """
  def get_store_by_username(username) do
    from(s in Store)
    |> join(:inner, [s], u in User, on: s.user_id == u.id)
    |> where([s, u], u.username == ^username and s.is_default == true)
    |> Repo.one()
  end

  @doc """
  Ensures user has a default store. Creates one if it doesn't exist.
  """
  def ensure_default_store(user) do
    case get_default_store_by_user(user.id) do
      nil -> create_default_store(user)
      store -> {:ok, store}
    end
  end

  defp get_default_store_by_user(user_id) do
    IO.puts("=== GET_DEFAULT_STORE_BY_USER DEBUG ===")
    IO.puts("Looking for default store for user_id: #{user_id}")

    result = from(s in Store, where: s.user_id == ^user_id and s.is_default == true)
    |> Repo.one()

    IO.puts("Query result: #{inspect(result)}")
    result
  end

  defp create_default_store(user) do
    IO.puts("=== CREATE_DEFAULT_STORE DEBUG ===")
    IO.puts("User: #{inspect(user)}")

    store_attrs = %{
      name: user.username || user.name || "My Store",
      slug: user.username,
      description: "Welcome to #{user.username}'s store",
      user_id: user.id,
      is_default: true
    }

    IO.puts("Store attributes to create: #{inspect(store_attrs)}")

    result = create_store(store_attrs)
    IO.puts("Create store result: #{inspect(result)}")
    result
  end

  @doc """
  Cleans up Stripe account if user has no more stores.
  This prevents orphaned Stripe accounts.
  """
  def cleanup_orphaned_stripe_account(user_id) do
    # Check if user has any remaining stores
    user_stores = get_stores_by_user(user_id)

    if Enum.empty?(user_stores) do
      # User has no stores, check if they have a Stripe account
      kyc_record = StoreKYCContext.get_kyc_by_user_id(user_id)

      if kyc_record && kyc_record.stripe_account_id do
        # TODO: In the future, we could delete the Stripe account here
        # For now, we'll just log it
        IO.puts("User #{user_id} has no stores but has Stripe account #{kyc_record.stripe_account_id}")
        IO.puts("Consider implementing Stripe account deletion for cleanup")
      end
    end
  end


  @doc """
  Gets all stores that don't have Stripe accounts.
  Useful for identifying stores that need Stripe account creation.
  """
  def get_stores_without_stripe_accounts do
    from(s in Store,
      left_join: k in Shomp.Stores.StoreKYC, on: s.id == k.store_id,
      where: is_nil(k.stripe_account_id),
      select: s
    )
    |> Repo.all()
  end

  # Private functions

  defp create_stripe_connected_account_for_new_store(store) do
    IO.puts("=== CREATING STRIPE CONNECTED ACCOUNT FOR NEW STORE ===")
    IO.puts("Store ID: #{store.store_id}")
    IO.puts("User ID: #{store.user_id}")

    # Get user email from the user_id since the user association might not be loaded
    user = Shomp.Accounts.get_user!(store.user_id)
    IO.puts("User Email: #{user.email}")

    # Check if user already has a Stripe account (across all their stores)
    existing_kyc = StoreKYCContext.get_kyc_by_user_id(store.user_id)
    IO.puts("Existing KYC: #{inspect(existing_kyc)}")

    if existing_kyc && existing_kyc.stripe_account_id do
      # User already has a Stripe account, just link this store to it
      IO.puts("Linking new store #{store.store_id} to existing Stripe account: #{existing_kyc.stripe_account_id}")

      case StoreKYCContext.create_kyc(%{
        store_id: store.id,  # Use integer ID for foreign key
        stripe_account_id: existing_kyc.stripe_account_id,
        status: existing_kyc.status,
        charges_enabled: existing_kyc.charges_enabled,
        payouts_enabled: existing_kyc.payouts_enabled,
        onboarding_completed: existing_kyc.onboarding_completed
      }) do
        {:ok, _kyc} ->
          IO.puts("Successfully linked new store #{store.store_id} to existing Stripe account")
          {:ok, existing_kyc.stripe_account_id}
        {:error, reason} ->
          IO.puts("Failed to link new store to existing Stripe account: #{inspect(reason)}")
          {:error, reason}
      end
    else
      # Create a new Stripe Express account for this user
      IO.puts("Creating new Stripe Express account for user #{user.email}")

      case Stripe.Account.create(%{
        type: "express",
        country: "US",  # Users must be US based for shomp sales (501c3 compliance)
        email: user.email,
        business_type: "individual",
        requested_capabilities: ["card_payments", "transfers"],
        settings: %{
          payouts: %{
            schedule: %{
              interval: "daily"
            }
          }
        }
      }) do
        {:ok, stripe_account} ->
          IO.puts("Created Stripe account: #{stripe_account.id}")

          # Create KYC record for this store with the new Stripe account ID
          case StoreKYCContext.create_kyc(%{
            store_id: store.id,  # Use integer ID for foreign key
            stripe_account_id: stripe_account.id,
            status: "pending",
            charges_enabled: false,
            payouts_enabled: false,
            onboarding_completed: false
          }) do
            {:ok, _kyc} ->
              IO.puts("Successfully created KYC record for new store #{store.store_id}")
              {:ok, stripe_account.id}
            {:error, reason} ->
              IO.puts("Failed to create KYC record: #{inspect(reason)}")
              {:error, reason}
          end

        {:error, reason} ->
          IO.puts("Failed to create Stripe account: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp get_stripe_connected_account(store) do
    IO.puts("=== GETTING STRIPE CONNECTED ACCOUNT ===")
    IO.puts("Store ID: #{store.store_id}")
    IO.puts("User ID: #{store.user_id}")

    # Get the user's Stripe account (should already exist from store creation)
    existing_kyc = StoreKYCContext.get_kyc_by_user_id(store.user_id)
    IO.puts("Existing KYC for user: #{inspect(existing_kyc)}")

    if existing_kyc && existing_kyc.stripe_account_id do
      # User has a Stripe account, return it
      IO.puts("Found existing Stripe account: #{existing_kyc.stripe_account_id}")
      {:ok, existing_kyc.stripe_account_id}
    else
      # This should never happen if stores are created properly
      IO.puts("ERROR: No Stripe account found for user #{store.user_id}")
      IO.puts("This indicates a problem with store creation - every store should have a Stripe account")
      {:error, :no_stripe_account}
    end
  end
end
