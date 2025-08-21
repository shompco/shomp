defmodule Shomp.Carts do
  @moduledoc """
  The Carts context for managing shopping carts.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Carts.{Cart, CartItem}
  alias Shomp.Products.Product
  alias Shomp.Stores

  @doc """
  Gets or creates an active cart for a user in a specific store.
  """
  def get_or_create_cart(user_id, store_id) do
    case get_active_cart(user_id, store_id) do
      nil ->
        create_cart(%{user_id: user_id, store_id: store_id})
      cart ->
        {:ok, cart}
    end
  end

  @doc """
  Gets the active cart for a user in a specific store.
  """
  def get_active_cart(user_id, store_id) do
    Cart
    |> where([c], c.user_id == ^user_id and c.store_id == ^store_id and c.status == "active")
    |> preload([cart_items: [product: []]])
    |> Repo.one()
  end

  @doc """
  Gets a cart by ID with all associations loaded.
  """
  def get_cart!(id) do
    Cart
    |> Repo.get!(id)
    |> Repo.preload([cart_items: [product: []]])
  end

  @doc """
  Gets all active carts for a user.
  """
  def list_user_carts(user_id) do
    Cart
    |> where([c], c.user_id == ^user_id and c.status == "active")
    |> preload([cart_items: [product: []]])
    |> Repo.all()
    |> Enum.map(fn cart ->
      # Manually fetch the store data using the store_id
      case Shomp.Stores.get_store_by_store_id(cart.store_id) do
        nil -> 
          # If store not found, create a placeholder
          %{cart | store: %{name: "Unknown Store", slug: "unknown"}}
        store -> 
          # Add the store data to the cart struct
          Map.put(cart, :store, store)
      end
    end)
  end

  @doc """
  Creates a new cart.
  """
  def create_cart(attrs \\ %{}) do
    %Cart{}
    |> Cart.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Adds a product to a cart.
  """
  def add_to_cart(cart_id, product_id, quantity \\ 1) do
    # Get the product to get the current price
    product = Repo.get!(Product, product_id)
    
    # Check if item already exists in cart
    case get_cart_item(cart_id, product_id) do
      nil ->
        # Create new cart item
        %CartItem{}
        |> CartItem.create_changeset(%{
          cart_id: cart_id,
          product_id: product_id,
          quantity: quantity,
          price: product.price
        })
        |> Repo.insert()
        |> case do
          {:ok, cart_item} ->
            # Try to update cart total, but don't fail if it doesn't work
            update_cart_total(cart_id)
            {:ok, cart_item}
          {:error, changeset} ->
            {:error, changeset}
        end
      
      _existing_item ->
        # Item already exists in cart - return specific error
        {:error, :item_already_in_cart}
    end
  end

  @doc """
  Removes a product from a cart.
  """
  def remove_from_cart(cart_id, product_id) do
    case get_cart_item(cart_id, product_id) do
      nil ->
        {:error, :not_found}
      
      cart_item ->
        Repo.delete(cart_item)
        |> case do
          {:ok, _} ->
            # Try to update cart total, but don't fail if it doesn't work
            update_cart_total(cart_id)
            {:ok, :removed}
          {:error, _} ->
            {:error, :delete_failed}
        end
    end
  end

  @doc """
  Updates the quantity of a cart item.
  """
  def update_cart_item_quantity(cart_item_id, quantity) do
    cart_item = Repo.get!(CartItem, cart_item_id)
    
    IO.puts("=== UPDATING CART ITEM QUANTITY ===")
    IO.puts("Cart Item ID: #{cart_item_id}")
    IO.puts("Current Quantity: #{cart_item.quantity}")
    IO.puts("New Quantity: #{quantity}")
    
    cart_item
    |> CartItem.update_quantity_changeset(%{quantity: quantity})
    |> Repo.update()
    |> case do
      {:ok, updated_item} ->
        # Try to update cart total, but don't fail if it doesn't work
        update_cart_total(updated_item.cart_id)
        {:ok, updated_item}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a specific cart item.
  """
  def get_cart_item(cart_id, product_id) do
    CartItem
    |> where([ci], ci.cart_id == ^cart_id and ci.product_id == ^product_id)
    |> Repo.one()
  end

  @doc """
  Gets all items in a cart.
  """
  def list_cart_items(cart_id) do
    CartItem
    |> where([ci], ci.cart_id == ^cart_id)
    |> preload([product: []])
    |> Repo.all()
  end

  @doc """
  Calculates the total amount for a cart.
  """
  def calculate_cart_total(cart_id) do
    CartItem
    |> where([ci], ci.cart_id == ^cart_id)
    |> select([ci], sum(fragment("? * ?", ci.price, ci.quantity)))
    |> Repo.one()
    |> case do
      nil -> Decimal.new(0)
      total -> total
    end
  end

  @doc """
  Updates the cart total amount.
  """
  def update_cart_total(cart_id) do
    total = calculate_cart_total(cart_id)
    
    cart = Repo.get!(Cart, cart_id)
    cart
    |> Cart.update_total_changeset(total)
    |> Repo.update()
    |> case do
      {:ok, updated_cart} -> {:ok, updated_cart}
      {:error, _changeset} -> {:error, :update_failed}
    end
  end

  @doc """
  Clears all items from a cart.
  """
  def clear_cart(cart_id) do
    CartItem
    |> where([ci], ci.cart_id == ^cart_id)
    |> Repo.delete_all()
    
    update_cart_total(cart_id)
    {:ok, :cleared}
  end

  @doc """
  Completes a cart (changes status to completed).
  """
  def complete_cart(cart_id) do
    cart = Repo.get!(Cart, cart_id)
    
    cart
    |> Cart.changeset(%{status: "completed"})
    |> Repo.update()
  end

  @doc """
  Abandons a cart (changes status to abandoned).
  """
  def abandon_cart(cart_id) do
    cart = Repo.get!(Cart, cart_id)
    
    cart
    |> Cart.changeset(%{status: "abandoned"})
    |> Repo.update()
  end

  @doc """
  Gets cart statistics for a user.
  """
  def get_user_cart_stats(user_id) do
    total_carts = Cart |> where([c], c.user_id == ^user_id) |> Repo.aggregate(:count, :id)
    active_carts = Cart |> where([c], c.user_id == ^user_id and c.status == "active") |> Repo.aggregate(:count, :id)
    completed_carts = Cart |> where([c], c.user_id == ^user_id and c.status == "completed") |> Repo.aggregate(:count, :id)
    
    total_spent = Cart
    |> where([c], c.user_id == ^user_id and c.status == "completed")
    |> select([c], sum(c.total_amount))
    |> Repo.one()
    |> case do
      nil -> Decimal.new(0)
      total -> total
    end
    
    %{
      total_carts: total_carts,
      active_carts: active_carts,
      completed_carts: completed_carts,
      total_spent: total_spent
    }
  end

  @doc """
  Gets cart statistics for a store.
  """
  def get_store_cart_stats(store_id) do
    total_carts = Cart |> where([c], c.store_id == ^store_id) |> Repo.aggregate(:count, :id)
    active_carts = Cart |> where([c], c.store_id == ^store_id and c.status == "active") |> Repo.aggregate(:count, :id)
    completed_carts = Cart |> where([c], c.store_id == ^store_id and c.status == "completed") |> Repo.aggregate(:count, :id)
    
    total_revenue = Cart
    |> where([c], c.store_id == ^store_id and c.status == "completed")
    |> select([c], sum(c.total_amount))
    |> Repo.one()
    |> case do
      nil -> Decimal.new(0)
      total -> total
    end
    
    %{
      total_carts: total_carts,
      active_carts: active_carts,
      completed_carts: completed_carts,
      total_revenue: total_revenue
    }
  end

  @doc """
  Cleans up abandoned carts older than specified days.
  """
  def cleanup_abandoned_carts(days_old \\ 30) do
    cutoff_date = Date.add(Date.utc_today(), -days_old)
    
    Cart
    |> where([c], c.status == "abandoned" and fragment("?::date", c.inserted_at) < ^cutoff_date)
    |> Repo.delete_all()
  end
end
