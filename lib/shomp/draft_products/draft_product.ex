defmodule Shomp.DraftProducts.DraftProduct do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :integer

  schema "draft_products" do
    field :title, :string
    field :description, :string
    field :price, :decimal
    field :type, :string
    field :store_id, :string
    field :category_id, :integer
    field :custom_category_id, :integer
    field :quantity, :integer, default: 0

    # R2 file URLs
    field :image_original_url, :string
    field :image_thumb_url, :string
    field :image_medium_url, :string
    field :image_large_url, :string
    field :image_extra_large_url, :string
    field :image_ultra_url, :string
    field :additional_images_urls, {:array, :string}, default: []
    field :digital_file_url, :string
    field :digital_file_type, :string

    # Metadata
    field :status, :string, default: "draft"
    field :user_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(draft_product, attrs) do
    draft_product
    |> cast(attrs, [
      :title, :description, :price, :type, :store_id, :category_id, :custom_category_id,
      :quantity, :image_original_url, :image_thumb_url, :image_medium_url, :image_large_url,
      :image_extra_large_url, :image_ultra_url, :additional_images_urls, :digital_file_url,
      :digital_file_type, :status, :user_id
    ])
    |> validate_required([:type, :store_id, :user_id])
    |> validate_inclusion(:type, ["digital", "physical"])
    |> validate_inclusion(:status, ["draft", "published", "archived"])
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
  end

  @doc false
  def create_changeset(draft_product, attrs) do
    draft_product
    |> changeset(attrs)
    |> put_change(:status, "draft")
  end
end
