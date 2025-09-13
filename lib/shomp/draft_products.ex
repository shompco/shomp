defmodule Shomp.DraftProducts do
  @moduledoc """
  The DraftProducts context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.DraftProducts.DraftProduct

  @doc """
  Returns the list of draft_products for a user.
  """
  def list_draft_products(user_id) do
    DraftProduct
    |> where([d], d.user_id == ^user_id)
    |> order_by([d], desc: d.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single draft_product.
  """
  def get_draft_product!(id), do: Repo.get!(DraftProduct, id)

  @doc """
  Gets a single draft_product by id and user_id.
  """
  def get_draft_product!(id, user_id) do
    DraftProduct
    |> where([d], d.id == ^id and d.user_id == ^user_id)
    |> Repo.one!()
  end

  @doc """
  Creates a draft_product.
  """
  def create_draft_product(attrs \\ %{}) do
    %DraftProduct{}
    |> DraftProduct.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a draft_product.
  """
  def update_draft_product(%DraftProduct{} = draft_product, attrs) do
    draft_product
    |> DraftProduct.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a draft_product.
  """
  def delete_draft_product(%DraftProduct{} = draft_product) do
    Repo.delete(draft_product)
  end

  @doc """
  Converts a draft product to a permanent product.
  """
  def convert_to_product(%DraftProduct{} = draft_product) do
    # This will be implemented when we integrate with the Products context
    {:ok, draft_product}
  end

  @doc """
  Gets or creates a draft product for a user and store.
  """
  def get_or_create_draft_product(user_id, store_id) do
    case get_latest_draft_product(user_id, store_id) do
      nil -> create_draft_product(%{user_id: user_id, store_id: store_id, type: "physical"})
      draft_product -> {:ok, draft_product}
    end
  end

  defp get_latest_draft_product(user_id, store_id) do
    DraftProduct
    |> where([d], d.user_id == ^user_id and d.store_id == ^store_id and d.status == "draft")
    |> order_by([d], desc: d.inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
