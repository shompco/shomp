defmodule Shomp.Categories.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :position, :integer, default: 0
    field :level, :integer, default: 0
    field :active, :boolean, default: true
    
    # Hierarchical structure for future extensibility
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  A category changeset for creation and updates.
  """
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :description, :position, :level, :active, :parent_id])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:slug, min: 2, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_level_constraints()
    |> validate_slug_format()
    |> unique_constraint(:slug)
    |> validate_parent_exists()
    |> calculate_level()
    |> maybe_generate_slug()
  end

  @doc """
  A category changeset for creation.
  """
  def create_changeset(category, attrs) do
    category
    |> changeset(attrs)
  end

  # Validations
  defp validate_level_constraints(changeset) do
    level = get_change(changeset, :level) || get_field(changeset, :level)
    
    if level && (level < 0 or level > 2) do
      add_error(changeset, :level, "must be between 0 and 2")
    else
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

  defp validate_parent_exists(changeset) do
    parent_id = get_change(changeset, :parent_id)
    
    if parent_id && parent_id != get_field(changeset, :parent_id) do
      case Shomp.Repo.get(Shomp.Categories.Category, parent_id) do
        nil -> add_error(changeset, :parent_id, "parent category does not exist")
        parent -> 
          # Ensure parent level allows this as a child
          validate_parent_level(changeset, parent)
      end
    else
      changeset
    end
  end

  defp validate_parent_level(changeset, parent) do
    case parent.level do
      0 -> changeset  # Main category can have sub categories
      1 -> changeset  # Sub category can have sub-sub categories  
      _ -> add_error(changeset, :parent_id, "cannot add sub-sub categories to this level")
    end
  end

  defp calculate_level(changeset) do
    parent_id = get_change(changeset, :parent_id) || get_field(changeset, :parent_id)
    
    if parent_id do
      case Shomp.Repo.get(Shomp.Categories.Category, parent_id) do
        nil -> changeset
        parent -> put_change(changeset, :level, parent.level + 1)
      end
    else
      put_change(changeset, :level, 0)
    end
  end

  defp maybe_generate_slug(changeset) do
    slug = get_change(changeset, :slug) || get_field(changeset, :slug)
    
    if slug do
      changeset
    else
      name = get_change(changeset, :name) || get_field(changeset, :name)
      if name do
        generated_slug = name
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9\s]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.trim("-")
        
        put_change(changeset, :slug, generated_slug)
      else
        changeset
      end
    end
  end

  # Helper functions for the hierarchical structure
  @doc """
  Returns true if this is a main category (level 0).
  """
  def main_category?(%__MODULE__{level: 0}), do: true
  def main_category?(_), do: false

  @doc """
  Returns true if this is a sub category (level 1).
  """
  def sub_category?(%__MODULE__{level: 1}), do: true
  def sub_category?(_), do: false

  @doc """
  Returns true if this is a sub-sub category (level 2).
  """
  def sub_sub_category?(%__MODULE__{level: 2}), do: true
  def sub_sub_category?(_), do: false

  @doc """
  Returns the display name with appropriate indentation.
  """
  def display_name(%__MODULE__{name: name, level: level}) do
    case level do
      0 -> name
      1 -> "  #{name}"
      2 -> "    #{name}"
      _ -> name
    end
  end

  @doc """
  Returns the full hierarchical path.
  """
  def full_path(%__MODULE__{} = category) do
    case category.parent_id do
      nil -> category.name
      parent_id ->
        case Shomp.Repo.get(Shomp.Categories.Category, parent_id) do
          nil -> category.name
          parent -> "#{full_path(parent)} > #{category.name}"
        end
    end
  end
end
