defmodule Shomp.PurchaseActivities.PurchaseActivity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id
  schema "purchase_activities" do
    field :order_id, :binary_id
    field :product_id, :id
    field :buyer_id, :id
    field :buyer_initials, :string
    field :buyer_location, :string
    field :product_title, :string
    field :product_url, :string
    field :amount, :decimal
    field :is_public, :boolean, default: true
    field :displayed_at, :utc_datetime
    field :display_count, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(purchase_activity, attrs) do
    purchase_activity
    |> cast(attrs, [
      :order_id,
      :product_id,
      :buyer_id,
      :buyer_initials,
      :buyer_location,
      :product_title,
      :product_url,
      :amount,
      :is_public,
      :displayed_at,
      :display_count
    ])
    |> validate_required([
      :order_id,
      :product_id,
      :buyer_id,
      :buyer_initials,
      :product_title,
      :amount
    ])
    |> validate_length(:buyer_initials, max: 10)
    |> validate_length(:product_title, max: 255)
    |> validate_number(:amount, greater_than: 0)
  end
end
