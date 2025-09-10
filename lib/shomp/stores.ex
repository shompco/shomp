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
    case %Store{}
         |> Store.create_changeset(attrs)
         |> Repo.insert() do
      {:ok, store} = result ->
        # Create Stripe Connected Account immediately when store is created
        # This is more conservative - only create accounts for users who actually want to sell
        case create_stripe_connected_account(store) do
          {:ok, stripe_account_id} ->
            IO.puts("Created Stripe Connected Account: #{stripe_account_id} for store: #{store.store_id}")
          {:error, reason} ->
            IO.puts("Failed to create Stripe Connected Account for store #{store.store_id}: #{inspect(reason)}")
            # Don't fail store creation if Stripe account creation fails
            # The store can still be created and Stripe account created later
        end

        # Broadcast to admin dashboard
        Phoenix.PubSub.broadcast(Shomp.PubSub, "admin:stores", %{
          event: "store_created",
          payload: store
        })
        result
      error -> error
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
  Ensures a Stripe Connected Account exists for a store.
  Creates one if it doesn't exist.
  """
  def ensure_stripe_connected_account(store_id) do
    store = get_store_by_store_id(store_id)
    if store do
      create_stripe_connected_account(store)
    else
      {:error, :store_not_found}
    end
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

  # Private functions

  defp create_stripe_connected_account(store) do
    # Check if user already has a Stripe account (across all their stores)
    existing_kyc = StoreKYCContext.get_kyc_by_user_id(store.user_id)

    if existing_kyc && existing_kyc.stripe_account_id do
      # User already has a Stripe account, just link this store to it
      case StoreKYCContext.create_kyc(%{
        store_id: store.store_id,
        stripe_account_id: existing_kyc.stripe_account_id,
        status: existing_kyc.status,
        charges_enabled: existing_kyc.charges_enabled,
        payouts_enabled: existing_kyc.payouts_enabled,
        onboarding_completed: existing_kyc.onboarding_completed
      }) do
        {:ok, _kyc} ->
          {:ok, existing_kyc.stripe_account_id}
        {:error, reason} ->
          IO.puts("Failed to link store to existing Stripe account: #{inspect(reason)}")
          {:error, reason}
      end
    else
      # Create a new Stripe Express account for this user
      case Stripe.Account.create(%{
        type: "express",
        country: "US",  # Default to US, can be made configurable later
        email: store.user.email,
        business_type: "individual",
        capabilities: %{
          card_payments: %{requested: true},
          transfers: %{requested: true}
        },
        settings: %{
          payouts: %{
            schedule: %{
              interval: "daily"
            }
          }
        }
      }) do
        {:ok, stripe_account} ->
          # Create KYC record for this store with the new Stripe account ID
          case StoreKYCContext.create_kyc(%{
            store_id: store.store_id,
            stripe_account_id: stripe_account.id,
            status: "pending",
            charges_enabled: false,
            payouts_enabled: false,
            onboarding_completed: false
          }) do
            {:ok, _kyc} ->
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
end
