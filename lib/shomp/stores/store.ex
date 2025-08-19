defmodule Shomp.Stores.Store do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Accounts.User

  schema "stores" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :store_id, :string  # Immutable store identifier
    belongs_to :user, User
    has_many :products, Shomp.Products.Product
    has_many :carts, Shomp.Carts.Cart
    has_one :store_balance, Shomp.Stores.StoreBalance
    has_one :store_kyc, Shomp.Stores.StoreKYC

    timestamps(type: :utc_datetime)
  end

  @doc """
  A store changeset for creation and updates.
  """
  def changeset(store, attrs) do
    store
    |> cast(attrs, [:name, :slug, :description, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:slug, min: 3, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "must contain only lowercase letters, numbers, and hyphens")
    |> validate_length(:description, max: 1000)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  A store changeset for creation.
  """
  def create_changeset(store, attrs) do
    store
    |> cast(attrs, [:name, :slug, :description, :user_id])
    |> generate_slug()
    |> generate_store_id()
    |> validate_required([:name, :slug, :user_id, :store_id])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:slug, min: 3, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "must contain only lowercase letters, numbers, and hyphens")
    |> validate_length(:description, max: 1000)
    |> unique_constraint(:slug)
    |> unique_constraint(:store_id)
    |> foreign_key_constraint(:user_id)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        name = get_change(changeset, :name)
        if name do
          slug = name
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9\s]/, "")
          |> String.replace(~r/\s+/, "-")
          |> String.trim("-")
          
          put_change(changeset, :slug, slug)
        else
          changeset
        end
      _ ->
        changeset
    end
  end

  defp generate_store_id(changeset) do
    case get_change(changeset, :store_id) do
      nil ->
        # Generate a unique, immutable store ID
        store_id = Ecto.UUID.generate()
        put_change(changeset, :store_id, store_id)
      _ ->
        changeset
    end
  end
end
