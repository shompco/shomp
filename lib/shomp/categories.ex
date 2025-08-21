defmodule Shomp.Categories do
  @moduledoc """
  The Categories context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Categories.Category

  @doc """
  Returns the list of categories.
  """
  def list_categories do
    Repo.all(Category)
  end

  @doc """
  Returns the list of main categories (level 0).
  """
  def list_main_categories do
    Category
    |> where([c], is_nil(c.parent_id))
    |> order_by([c], c.position)
    |> Repo.all()
  end

  @doc """
  Returns the list of sub categories (level 1).
  """
  def list_sub_categories do
    Category
    |> where([c], c.level == 1)
    |> order_by([c], c.position)
    |> Repo.all()
  end

  @doc """
  Returns the list of sub-sub categories (level 2).
  """
  def list_sub_sub_categories do
    Category
    |> where([c], c.level == 2)
    |> order_by([c], c.position)
    |> Repo.all()
  end

  @doc """
  Returns the list of sub categories for a given main category.
  """
  def list_sub_categories_for_main(main_category_id) do
    Category
    |> where([c], c.parent_id == ^main_category_id)
    |> order_by([c], c.position)
    |> Repo.all()
  end

  @doc """
  Returns the list of sub-sub categories for a given sub category.
  """
  def list_sub_sub_categories_for_sub(sub_category_id) do
    Category
    |> where([c], c.parent_id == ^sub_category_id)
    |> order_by([c], c.position)
    |> Repo.all()
  end

  @doc """
  Returns the list of categories for a specific level.
  """
  def list_categories_by_level(level) do
    Category
    |> where([c], c.level == ^level)
    |> order_by([c], c.position)
    |> Repo.all()
  end

  @doc """
  Gets a single category.
  """
  def get_category!(id), do: Repo.get!(Category, id)

  @doc """
  Gets a single category by slug.
  """
  def get_category_by_slug!(slug), do: Repo.get_by!(Category, slug: slug)

  @doc """
  Creates a category.
  """
  def create_category(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category.
  """
  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category.
  """
  def delete_category(%Category{} = category) do
    Repo.delete(category)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking category changes.
  """
  def change_category(%Category{} = category, attrs \\ %{}) do
    Category.changeset(category, attrs)
  end

  @doc """
  Returns a hierarchical tree of categories.
  """
  def get_category_tree do
    main_categories = list_main_categories()
    
    Enum.map(main_categories, fn main ->
      %{main | children: get_sub_categories_recursive(main.id)}
    end)
  end

  defp get_sub_categories_recursive(parent_id) do
    children = list_sub_categories_for_main(parent_id)
    
    Enum.map(children, fn child ->
      %{child | children: list_sub_sub_categories_for_sub(child.id)}
    end)
  end

  @doc """
  Returns all categories formatted for select options.
  """
  def get_category_options do
    Category
    |> where([c], c.active == true)
    |> order_by([c], [c.level, c.position])
    |> select([c], {c.name, c.id})
    |> Repo.all()
  end

  @doc """
  Returns main categories formatted for select options.
  These are the level 1 categories that users actually select from.
  """
  def get_main_category_options do
    Category
    |> where([c], c.level == 1 and c.active == true)
    |> order_by([c], c.position)
    |> select([c], {c.name, c.id})
    |> Repo.all()
  end

  @doc """
  Returns sub categories formatted for select options.
  """
  def get_sub_category_options do
    Category
    |> where([c], c.level == 1 and c.active == true)
    |> order_by([c], c.position)
    |> select([c], {c.name, c.id})
    |> Repo.all()
  end

  @doc """
  Returns sub categories for a specific main category, formatted for select options.
  """
  def get_sub_category_options_for_main(main_category_id) do
    Category
    |> where([c], c.parent_id == ^main_category_id and c.active == true)
    |> order_by([c], c.position)
    |> select([c], {c.name, c.id})
    |> Repo.all()
  end

  @doc """
  Returns sub-sub categories for a specific sub category, formatted for select options.
  """
  def get_sub_sub_category_options_for_sub(sub_category_id) do
    Category
    |> where([c], c.parent_id == ^sub_category_id and c.active == true)
    |> order_by([c], c.position)
    |> select([c], {c.name, c.id})
    |> Repo.all()
  end

  @doc """
  Returns categories filtered by product type (physical or digital).
  """
  def get_categories_by_type(product_type) do
    case product_type do
      "physical" ->
        # Get categories under Physical Goods (parent_id = physical_goods_id)
        physical_goods = get_category_by_slug!("physical-goods")
        list_sub_categories_for_main(physical_goods.id)
        |> Enum.map(fn cat -> {cat.name, cat.id} end)
      
      "digital" ->
        # Get categories under Digital Goods (parent_id = digital_goods_id)
        digital_goods = get_category_by_slug!("digital-goods")
        list_sub_categories_for_main(digital_goods.id)
        |> Enum.map(fn cat -> {cat.name, cat.id} end)
      
      _ ->
        []
    end
  end
end
