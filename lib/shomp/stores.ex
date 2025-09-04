defmodule Shomp.Stores do
  @moduledoc """
  The Stores context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Stores.Store

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
end
