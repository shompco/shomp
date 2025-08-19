defmodule Shomp.Products.Product do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Stores.Store

  schema "products" do
    field :title, :string
    field :description, :string
    field :price, :decimal
    field :type, :string
    field :file_path, :string
    field :stripe_product_id, :string
    belongs_to :store, Store
    has_many :payments, Shomp.Payments.Payment
    has_many :downloads, Shomp.Downloads.Download

    timestamps(type: :utc_datetime)
  end

  @doc """
  A product changeset for creation and updates.
  """
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:title, :description, :price, :type, :file_path, :store_id, :stripe_product_id])
    |> validate_required([:title, :price, :type, :store_id])
    |> validate_length(:title, min: 2, max: 200)
    |> validate_length(:description, max: 2000)
    |> validate_number(:price, greater_than: 0)
    |> validate_inclusion(:type, ["digital", "physical", "service"])
    |> validate_length(:file_path, max: 500)
    |> foreign_key_constraint(:store_id)
  end

  @doc """
  A product changeset for creation.
  """
  def create_changeset(product, attrs) do
    product
    |> changeset(attrs)
    |> validate_file_path_for_type()
  end

  defp validate_file_path_for_type(changeset) do
    type = get_change(changeset, :type)
    file_path = get_change(changeset, :file_path)

    case {type, file_path} do
      {"digital", nil} ->
        add_error(changeset, :file_path, "is required for digital products")
      {"digital", ""} ->
        add_error(changeset, :file_path, "is required for digital products")
      _ ->
        changeset
    end
  end
end
