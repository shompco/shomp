defmodule Shomp.Products do
  @moduledoc """
  The Products context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Products.Product


  @doc """
  Returns the list of products.
  """
  def list_products do
    Repo.all(Product)
  end

  @doc """
  Returns the list of products for a specific store.
  """
  def list_products_by_store(store_id) do
    Product
    |> where([p], p.store_id == ^store_id)
    |> Repo.all()
    |> Enum.map(fn product ->
      # Load store data
      case Shomp.Stores.get_store_by_store_id(product.store_id) do
        nil -> product
        store ->
          product = Map.put(product, :store, store)

          # Load platform category if it exists
          if product.category_id do
            case Repo.get(Shomp.Categories.Category, product.category_id) do
              nil -> product
              category -> Map.put(product, :category, category)
            end
          else
            product
          end
          |> then(fn product ->
            # Load custom category if it exists
            if product.custom_category_id do
              case Repo.get(Shomp.Categories.Category, product.custom_category_id) do
                nil -> product
                custom_category -> Map.put(product, :custom_category, custom_category)
              end
            else
              product
            end
          end)
      end
    end)
  end

  @doc """
  Lists products for a user's default store.
  """
  def list_user_products(user) do
    store = Shomp.Stores.get_user_default_store(user)
    if store do
      list_products_by_store(store.store_id)
    else
      []
    end
  end

  @doc """
  Creates a product for a user's default store.
  Creates a default store if one doesn't exist.
  """
  def create_user_product(user, attrs) do
    case Shomp.Stores.get_user_default_store(user) do
      nil ->
        # Create a default store for the user
        store_attrs = %{
          name: user.username,
          slug: user.username,
          description: "Default store for #{user.username}",
          user_id: user.id
        }

        case Shomp.Stores.create_store(store_attrs) do
          {:ok, store} ->
            create_product(Map.put(attrs, "store_id", store.store_id))
          {:error, changeset} ->
            {:error, changeset}
        end

      store ->
        create_product(Map.put(attrs, "store_id", store.store_id))
    end
  end

  @doc """
  Gets a product by username and product slug.
  """
  def get_product_by_username_and_slug(username, product_slug) do
    from(p in Product)
    |> join(:inner, [p], s in Shomp.Stores.Store, on: p.store_id == s.store_id)
    |> join(:inner, [p, s], u in Shomp.Accounts.User, on: s.user_id == u.id)
    |> where([p, s, u], u.username == ^username and p.slug == ^product_slug)
    |> preload([:store, :category, store: :user])
    |> Repo.one()
  end

  @doc """
  Gets a single product.

  Raises `Ecto.NoResultsError` if the Product does not exist.

  ## Examples

      iex> get_product!(123)
      %Product{}

      iex> get_product!(456)
      ** (Ecto.NoResultsError)

  """
  def get_product!(id), do: Repo.get!(Product, id)

  @doc """
  Gets a single product with store data loaded.

  Raises `Ecto.NoResultsError` if the Product does not exist.

  ## Examples

      iex> get_product_with_store!(123)
      %Product{store: %Store{}}

      iex> get_product_with_store!(456)
      ** (Ecto.NoResultsError)

  """
  def get_product_with_store!(id) do
    product = Repo.get!(Product, id)

    # Manually fetch the store data using the store_id with user preloaded
    case Shomp.Stores.get_store_by_store_id_with_user(product.store_id) do
      nil ->
        raise Ecto.NoResultsError, message: "Store not found for product"
      store ->
        # Add the store data to the product struct using the virtual field
        product = Map.put(product, :store, store)

        # Load platform category if it exists
        if product.category_id do
          case Repo.get(Shomp.Categories.Category, product.category_id) do
            nil -> product
            category -> Map.put(product, :category, category)
          end
        else
          product
        end
        |> then(fn product ->
          # Load custom category if it exists
          if product.custom_category_id do
            case Repo.get(Shomp.Categories.Category, product.custom_category_id) do
              nil -> product
              custom_category -> Map.put(product, :custom_category, custom_category)
            end
          else
            product
          end
        end)
    end
  end

  @doc """
  Creates a product.
  """
  def create_product(attrs \\ %{}) do
    IO.puts("=== CREATING PRODUCT ===")
    IO.puts("Attributes: #{inspect(attrs)}")

    %Product{}
    |> Product.create_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, product} ->
        IO.puts("Product created in DB with ID: #{product.id}")

        # Create Stripe product
        case create_stripe_product(product) do
          {:ok, stripe_product} ->
            IO.puts("Stripe product created: #{stripe_product.id}")

            # Update product with Stripe ID
            IO.puts("Updating product #{product.id} with Stripe ID: #{stripe_product.id}")
                    case product
        |> Product.changeset(%{stripe_product_id: stripe_product.id})
        |> Repo.update() do
          {:ok, updated_product} ->
            IO.puts("Product updated successfully with Stripe ID: #{updated_product.stripe_product_id}")

            # Broadcast to admin dashboard
            Phoenix.PubSub.broadcast(Shomp.PubSub, "admin:products", %{
              event: "product_created",
              payload: updated_product
            })

            {:ok, updated_product}

          {:error, changeset} ->
            IO.puts("Failed to update product with Stripe ID: #{inspect(changeset.errors)}")
            {:ok, product} # Return original product if update fails
        end

          {:error, reason} ->
            # Log the error but still return success
            # In production, you might want to handle this differently
            IO.puts("Warning: Failed to create Stripe product: #{inspect(reason)}")
            {:ok, product}
        end

      error ->
        IO.puts("Failed to create product: #{inspect(error)}")
        error
    end
  end

  @doc """
  Syncs a product with Stripe (creates Stripe product if missing).
  """
  def sync_product_with_stripe(%Product{} = product) do
    if product.stripe_product_id do
      {:ok, product}
    else
      case create_stripe_product(product) do
        {:ok, stripe_product} ->
          product
          |> Product.changeset(%{stripe_product_id: stripe_product.id})
          |> Repo.update()

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Syncs all products without Stripe IDs.
  """
  def sync_all_products_with_stripe do
    Product
    |> where([p], is_nil(p.stripe_product_id))
    |> Repo.all()
    |> Enum.map(&sync_product_with_stripe/1)
  end

  @doc """
  Updates a product.
  """
  def update_product(%Product{} = product, attrs) do
    IO.puts("=== UPDATE PRODUCT ===")
    IO.puts("Product ID: #{product.id}")
    IO.puts("Update attrs: #{inspect(attrs)}")

    changeset = product |> Product.changeset(attrs)
    IO.puts("Changeset changes: #{inspect(changeset.changes)}")
    IO.puts("Changeset errors: #{inspect(changeset.errors)}")

    changeset
    |> Repo.update()
    |> case do
      {:ok, updated_product} ->
        # Update Stripe product if price or description changed
        if Map.has_key?(attrs, :price) or Map.has_key?(attrs, :description) or Map.has_key?(attrs, :title) do
          update_stripe_product(updated_product)
        end
        {:ok, updated_product}

      error -> error
    end
  end

  @doc """
  Deletes a product.
  """
  def delete_product(%Product{} = product) do
    # Delete Stripe product and prices if they exist
    if product.stripe_product_id do
      delete_stripe_product_and_prices(product.stripe_product_id)
    end

    Repo.delete(product)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking product changes.

  ## Examples

      iex> change_product(product)
      %Ecto.Changeset{data: %Product{}}

  """
  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for creating a product.

  ## Examples

      iex> change_product_creation(product)
      %Ecto.Changeset{data: %Product{}}

  """
  def change_product_creation(%Product{} = product, attrs \\ %{}) do
    Product.create_changeset(product, attrs)
  end

  @doc """
  Counts the number of products for a specific user across all their stores.
  """
  def count_user_products(user_id) do
    # Get all stores for the user
    store_ids = Shomp.Stores.list_stores_by_user(user_id) |> Enum.map(& &1.store_id)

    if Enum.empty?(store_ids) do
      0
    else
      Product
      |> where([p], p.store_id in ^store_ids)
      |> Repo.aggregate(:count, :id)
    end
  end

  @doc """
  Counts the number of products for a specific store.
  """
  def count_store_products(store_id) do
    Product
    |> where([p], p.store_id == ^store_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets the latest products with store information for the home page.
  """
  def get_latest_products(limit \\ 8) do
    Product
    |> preload([:category, :custom_category])
    |> order_by([p], [desc: p.inserted_at])
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(fn product ->
      # Load store data manually since it's a virtual field
      case Shomp.Stores.get_store_by_store_id(product.store_id) do
        nil -> product
        store -> Map.put(product, :store, store)
      end
    end)
  end

  @doc """
  Gets featured products for the Editor's Picks section.
  """
  def get_featured_products(limit \\ 2) do
    Product
    |> preload([:category, :custom_category])
    |> where([p], p.price > 20)  # Products with higher prices as "featured"
    |> order_by([p], [desc: p.price])
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(fn product ->
      # Load store data manually since it's a virtual field
      case Shomp.Stores.get_store_by_store_id(product.store_id) do
        nil -> product
        store -> Map.put(product, :store, store)
      end
    end)
  end

  @doc """
  Gets a product by slug within a specific store.
  """
  def get_product_by_store_slug(store_id, product_slug) do
    Product
    |> where([p], p.store_id == ^store_id and p.slug == ^product_slug)
    |> Repo.one()
    |> case do
      nil -> nil
      product ->
        # Load store data
        case Shomp.Stores.get_store_by_store_id(product.store_id) do
          nil -> product
          store ->
            product = Map.put(product, :store, store)

            # Load platform category if it exists
            if product.category_id do
              case Repo.get(Shomp.Categories.Category, product.category_id) do
                nil -> product
                category -> Map.put(product, :category, category)
              end
            else
              product
            end
            |> then(fn product ->
              # Load custom category if it exists
              if product.custom_category_id do
                case Repo.get(Shomp.Categories.Category, product.custom_category_id) do
                  nil -> product
                  custom_category -> Map.put(product, :custom_category, custom_category)
                end
              else
                product
              end
            end)
        end
    end
  end

  @doc """
  Gets a product by slug within a specific store and category.
  """
  def get_product_by_store_and_category_slug(store_id, category_id, product_slug) do
    Product
    |> where([p], p.store_id == ^store_id and p.custom_category_id == ^category_id and p.slug == ^product_slug)
    |> Repo.one()
    |> case do
      nil -> nil
      product ->
        # Load store data
        case Shomp.Stores.get_store_by_store_id(product.store_id) do
          nil -> product
          store ->
            product = Map.put(product, :store, store)

            # Load platform category if it exists
            if product.category_id do
              case Repo.get(Shomp.Categories.Category, product.category_id) do
                nil -> product
                category -> Map.put(product, :category, category)
              end
            else
              product
            end
            |> then(fn product ->
              # Load custom category if it exists
              if product.custom_category_id do
                case Repo.get(Shomp.Categories.Category, product.custom_category_id) do
                  nil -> product
                  custom_category -> Map.put(product, :custom_category, custom_category)
                end
              else
                product
              end
            end)
        end
    end
  end

  @doc """
  Gets products by custom category with store information.
  """
  def get_products_by_custom_category(category_id, limit \\ 20) do
    Product
    |> where([p], p.custom_category_id == ^category_id)
    |> order_by([p], [desc: p.inserted_at])
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(fn product ->
      case Shomp.Stores.get_store_by_store_id(product.store_id) do
        nil -> product
        store ->
          product = Map.put(product, :store, store)

          # Load platform category if it exists
          if product.category_id do
            case Repo.get(Shomp.Categories.Category, product.category_id) do
              nil -> product
              category -> Map.put(product, :category, category)
            end
          else
            product
          end
          |> then(fn product ->
            # Load custom category if it exists
            if product.custom_category_id do
              case Repo.get(Shomp.Categories.Category, product.custom_category_id) do
                nil -> product
                custom_category -> Map.put(product, :custom_category, custom_category)
              end
            else
              product
            end
          end)
      end
    end)
  end

  @doc """
  Gets products by platform category with store information.
  """
  def get_products_by_category(category_id, limit \\ 20) do
    Product
    |> where([p], p.category_id == ^category_id)
    |> preload([:store, :category, :custom_category, store: :user])
    |> order_by([p], [desc: p.inserted_at])
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Counts the number of products in a specific category.
  """
  def count_products_by_category(category_id) do
    Product
    |> where([p], p.category_id == ^category_id)
    |> Repo.aggregate(:count, :id)
  end

  # Private functions

  defp create_stripe_product(product) do
    Stripe.Product.create(%{
      name: product.title,
      description: product.description,
      metadata: %{
        product_id: product.id,
        store_id: product.store_id,
        product_type: product.type
      }
    })
  end

  defp update_stripe_product(product) do
    if product.stripe_product_id do
      Stripe.Product.update(product.stripe_product_id, %{
        name: product.title,
        description: product.description
      })
    end
  end

  defp delete_stripe_product_and_prices(stripe_product_id) do
    # Delete associated Stripe prices first
    case Stripe.Price.list(%{product: stripe_product_id, active: true}) do
      %{data: prices} when is_list(prices) ->
        Enum.each(prices, fn price ->
          Stripe.Price.update(price.id, %{active: false})
        end)

      _ ->
        :ok
    end

    # Delete Stripe product
    Stripe.Product.delete(stripe_product_id)
  end
end
