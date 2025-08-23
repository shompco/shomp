defmodule Shomp.StoreCategories do
  @moduledoc """
  The StoreCategories context for managing store-specific custom categories.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Categories.Category

  @doc """
  Returns the list of store categories for a specific store.
  """
  def list_store_categories(store_id) do
    Category
    |> where([c], c.store_id == ^store_id)
    |> order_by([c], [asc: c.position, asc: c.name])
    |> Repo.all()
  end

  @doc """
  Gets a single store category by ID.
  """
  def get_store_category!(id), do: Repo.get!(Category, id)

  @doc """
  Gets a single store category by slug within a store.
  """
  def get_store_category_by_slug(store_id, slug) do
    Category
    |> where([c], c.store_id == ^store_id and c.slug == ^slug)
    |> Repo.one()
  end

  @doc """
  Creates a store category.
  """
  def create_store_category(attrs \\ %{}) do
    %Category{}
    |> Category.store_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a store category.
  """
  def update_store_category(%Category{} = category, attrs) do
    category
    |> Category.store_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a store category.
  """
  def delete_store_category(%Category{} = category) do
    Repo.delete(category)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking store category changes.
  """
  def change_store_category(%Category{} = category, attrs \\ %{}) do
    Category.store_changeset(category, attrs)
  end

  @doc """
  Gets store category options for select dropdowns.
  Returns a list of {name, id} tuples.
  """
  def get_store_category_options(store_id) do
    list_store_categories(store_id)
    |> Enum.map(fn category -> {category.name, category.id} end)
  end

  @doc """
  Gets store category options with "Select Category" option.
  """
  def get_store_category_options_with_default(store_id) do
    [{"Select Category", nil}] ++ get_store_category_options(store_id)
  end

  @doc """
  Checks if a store category slug is available within a store.
  """
  def slug_available?(store_id, slug, exclude_id \\ nil) do
    query = Category
    |> where([c], c.store_id == ^store_id and c.slug == ^slug)
    
    query = if exclude_id do
      query |> where([c], c.id != ^exclude_id)
    else
      query
    end
    
    Repo.aggregate(query, :count, :id) == 0
  end

  @doc """
  Gets the count of products in a store category.
  """
  def get_category_product_count(category_id) do
    Repo.aggregate(
      from(p in Shomp.Products.Product, where: p.custom_category_id == ^category_id),
      :count,
      :id
    )
  end

  @doc """
  Gets store categories with product counts.
  """
  def list_store_categories_with_counts(store_id) do
    categories = list_store_categories(store_id)
    
    Enum.map(categories, fn category ->
      count = get_category_product_count(category.id)
      Map.put(category, :product_count, count)
    end)
  end
end
