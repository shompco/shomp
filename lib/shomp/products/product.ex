defmodule Shomp.Products.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :title, :string
    field :description, :string
    field :price, :decimal
    field :type, :string
    field :file_path, :string
    field :stripe_product_id, :string
    field :store_id, :string  # Reference to store's immutable store_id
    field :store, :map, virtual: true  # Virtual field to hold store data
    field :slug, :string  # SEO-friendly URL slug
    
    # Product images
    field :image_original, :string
    field :image_thumb, :string
    field :image_medium, :string
    field :image_large, :string
    field :image_extra_large, :string
    field :image_ultra, :string
    field :additional_images, {:array, :string}, default: []
    field :primary_image_index, :integer, default: 0
    
    belongs_to :category, Shomp.Categories.Category  # Global platform category
    belongs_to :custom_category, Shomp.Categories.Category  # Store-specific category
    
    has_many :payments, Shomp.Payments.Payment
    has_many :downloads, Shomp.Downloads.Download

    timestamps(type: :utc_datetime)
  end

  @doc """
  A product changeset for creation and updates.
  """
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:title, :description, :price, :type, :file_path, :store_id, :stripe_product_id, :category_id, :custom_category_id, :slug, :image_original, :image_thumb, :image_medium, :image_large, :image_extra_large, :image_ultra, :additional_images, :primary_image_index])
    |> validate_required([:title, :price, :type, :store_id])
    |> validate_length(:title, min: 2, max: 200)
    |> validate_length(:description, max: 2000)
    |> validate_number(:price, greater_than: 0)
    |> validate_inclusion(:type, ["digital", "physical"])
    |> validate_length(:file_path, max: 500)
    |> validate_length(:store_id, min: 1)
    |> validate_slug_format()
    |> validate_image_paths()
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

    case {type, file_path} do
      {"digital", nil} ->
        add_error(changeset, :file_path, "is required for digital products")
      {"digital", ""} ->
        add_error(changeset, :file_path, "is required for digital products")
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
          if String.starts_with?(path, "/uploads/") do
            acc
          else
            add_error(acc, field, "must be a valid upload path")
          end
        _ ->
          add_error(acc, field, "must be a valid path string")
      end
    end)
  end
end
