defmodule Shomp.Products.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :immutable_id, :binary_id
    field :title, :string
    field :description, :string
    field :price, :decimal
    field :type, :string
    field :file_path, :string
    field :digital_file_url, :string
    field :digital_file_type, :string
    field :stripe_product_id, :string
    field :slug, :string  # SEO-friendly URL slug
    field :sold_out, :boolean, default: false  # For physical products
    field :quantity, :integer, default: 0  # Available quantity for physical products

    # Shipping fields for physical products
    field :weight, :decimal, default: 1.0
    field :length, :decimal, default: 6.0
    field :width, :decimal, default: 4.0
    field :height, :decimal, default: 2.0
    field :weight_unit, :string, default: "lb"
    field :distance_unit, :string, default: "in"

    # Product images
    field :image_original, :string
    field :image_thumb, :string
    field :image_medium, :string
    field :image_large, :string
    field :image_extra_large, :string
    field :image_ultra, :string
    field :additional_images, {:array, :string}, default: []
    field :primary_image_index, :integer, default: 0
    field :us_citizen_confirmation, :boolean, virtual: true  # Virtual field for US citizen checkbox

    belongs_to :store, Shomp.Stores.Store, foreign_key: :store_id, references: :store_id, type: :string
    belongs_to :category, Shomp.Categories.Category  # Global platform category
    belongs_to :custom_category, Shomp.Categories.Category  # Store-specific category

    has_many :payments, Shomp.Payments.Payment
    has_many :downloads, Shomp.Downloads.Download, foreign_key: :product_immutable_id, references: :immutable_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  A product changeset for creation and updates.
  """
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:title, :description, :price, :type, :file_path, :digital_file_url, :digital_file_type, :store_id, :stripe_product_id, :category_id, :custom_category_id, :slug, :image_original, :image_thumb, :image_medium, :image_large, :image_extra_large, :image_ultra, :additional_images, :primary_image_index, :sold_out, :quantity, :weight, :length, :width, :height, :weight_unit, :distance_unit])
    |> cast(attrs, [:us_citizen_confirmation], [])
    |> validate_required([:title, :price, :type, :store_id])
    |> validate_length(:title, min: 2, max: 200)
    |> validate_length(:description, max: 2000)
    |> validate_number(:price, greater_than: 0)
    |> validate_inclusion(:type, ["digital", "physical"])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> validate_length(:file_path, max: 500)
    |> validate_length(:store_id, min: 1)
    |> validate_slug_format()
    |> validate_image_paths()
    |> validate_us_citizen_confirmation()
  end

  @doc """
  A product changeset for creation.
  """
  def create_changeset(product, attrs) do
    product
    |> changeset(attrs)
    |> validate_file_path_for_type()
    |> generate_slug()
  end

  defp validate_file_path_for_type(changeset) do
    type = get_change(changeset, :type)
    file_path = get_change(changeset, :file_path)
    digital_file_url = get_change(changeset, :digital_file_url)

    case {type, file_path, digital_file_url} do
      {"digital", nil, nil} ->
        add_error(changeset, :digital_file_url, "is required for digital products")
      {"digital", nil, ""} ->
        add_error(changeset, :digital_file_url, "is required for digital products")
      {"digital", "", nil} ->
        add_error(changeset, :digital_file_url, "is required for digital products")
      {"digital", "", ""} ->
        add_error(changeset, :digital_file_url, "is required for digital products")
      _ ->
        changeset
    end
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        title = get_change(changeset, :title)
        if title do
          slug = title
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

  defp validate_slug_format(changeset) do
    slug = get_change(changeset, :slug) || get_field(changeset, :slug)

    if slug && not Regex.match?(~r/^[a-z0-9-]+$/, slug) do
      add_error(changeset, :slug, "must contain only lowercase letters, numbers, and hyphens")
    else
      changeset
    end
  end

  defp validate_image_paths(changeset) do
    # Validate image paths if they exist
    image_fields = [:image_original, :image_thumb, :image_medium, :image_large, :image_extra_large, :image_ultra]

    Enum.reduce(image_fields, changeset, fn field, acc ->
      case get_change(acc, field) do
        nil -> acc
        path when is_binary(path) and byte_size(path) > 0 ->
          if String.starts_with?(path, "/uploads/") or String.starts_with?(path, "https://") do
            acc
          else
            add_error(acc, field, "must be a valid upload path or URL")
          end
        _ ->
          add_error(acc, field, "must be a valid path string")
      end
    end)
  end

  defp validate_us_citizen_confirmation(changeset) do
    case get_change(changeset, :us_citizen_confirmation) do
      true -> changeset
      false -> add_error(changeset, :us_citizen_confirmation, "Shomp is only available to users based in the U.S. This ensures we can process payouts smoothly.")
      nil -> add_error(changeset, :us_citizen_confirmation, "Shomp is only available to users based in the U.S. This ensures we can process payouts smoothly.")
      _ -> add_error(changeset, :us_citizen_confirmation, "Shomp is only available to users based in the U.S. This ensures we can process payouts smoothly.")
    end
  end
end
