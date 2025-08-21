defmodule Shomp.Accounts.Tier do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "tiers" do
    field :name, :string
    field :slug, :string
    field :store_limit, :integer
    field :product_limit_per_store, :integer
    field :monthly_price, :decimal
    field :features, {:array, :string}
    field :is_active, :boolean
    field :sort_order, :integer
    
    has_many :users, Shomp.Accounts.User
    
    timestamps(type: :utc_datetime)
  end

  def changeset(tier, attrs) do
    tier
    |> cast(attrs, [:name, :slug, :store_limit, :product_limit_per_store, 
                    :monthly_price, :features, :is_active, :sort_order])
    |> validate_required([:name, :slug, :store_limit, :product_limit_per_store, :monthly_price])
    |> validate_number(:store_limit, greater_than: 0)
    |> validate_number(:product_limit_per_store, greater_than: 0)
    |> validate_number(:monthly_price, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
  end
end
