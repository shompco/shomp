defmodule Shomp.Stores.Store do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Accounts.User

  schema "stores" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :store_id, :string  # Immutable store identifier
    field :merchant_status, :string, default: "pending_verification"
    field :pending_balance, :decimal, default: 0
    field :available_balance, :decimal, default: 0
    belongs_to :user, User
    has_many :products, Shomp.Products.Product, foreign_key: :store_id, references: :store_id
    has_many :carts, Shomp.Carts.Cart, foreign_key: :store_id, references: :store_id
    has_one :store_balance, Shomp.Stores.StoreBalance
    has_one :store_kyc, Shomp.Stores.StoreKYC

    timestamps(type: :utc_datetime)
  end

  @doc """
  A store changeset for creation and updates.
  """
  def changeset(store, attrs) do
    store
    |> cast(attrs, [:name, :slug, :description, :user_id, :merchant_status, :pending_balance, :available_balance])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:slug, min: 3, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "must contain only lowercase letters, numbers, and hyphens")
    |> validate_inclusion(:merchant_status, ["pending_verification", "verified", "rejected"])
    |> validate_number(:pending_balance, greater_than_or_equal_to: 0)
    |> validate_number(:available_balance, greater_than_or_equal_to: 0)
    |> validate_length(:description, max: 1000)
    |> validate_store_username_conflict()
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
    |> validate_store_username_conflict()
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

  defp validate_store_username_conflict(changeset) do
    slug = get_change(changeset, :slug) || get_field(changeset, :slug)
    
    if slug do
      # Check if this store slug conflicts with any existing username
      case Shomp.Repo.get_by(Shomp.Accounts.User, username: slug) do
        nil -> changeset
        _user -> 
          add_error(changeset, :slug, "store name conflicts with existing username '#{slug}'. Please choose a different store name.")
      end
    else
      changeset
    end
  end
end
