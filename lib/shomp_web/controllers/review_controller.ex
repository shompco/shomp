defmodule ShompWeb.ReviewController do
  use ShompWeb, :controller

  alias Shomp.Reviews
  alias Shomp.Products
  alias Shomp.Orders

  def new(conn, %{"store_slug" => store_slug, "product_id" => product_id}) do
    user_id = conn.assigns.current_scope.user.id
    product_id = String.to_integer(product_id)
    
    # Get the product
    product = Products.get_product_with_store!(product_id)
    
    # Verify the product belongs to the store with the given slug
    if product.store.slug != store_slug do
      conn
      |> put_flash(:error, "Product not found in this store")
      |> redirect(to: ~p"/stores/#{store_slug}")
    else
      # Check if user has already reviewed this product
      if Reviews.user_has_reviewed_product?(user_id, product_id) do
        conn
        |> put_flash(:error, "You have already reviewed this product")
        |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
      else
        # Check if user has purchased this product
        if Orders.user_purchased_product?(user_id, product_id) do
          # Get user's orders for this product to select which order to reference
          user_orders = Orders.get_user_orders_with_product(user_id, product_id)
          
          # If there's only one order, pre-select it
          changeset = if length(user_orders) == 1 do
            Reviews.change_review(%Shomp.Reviews.Review{}, %{order_id: List.first(user_orders).id})
          else
            Reviews.change_review(%Shomp.Reviews.Review{})
          end
          
          conn
          |> assign(:product, product)
          |> assign(:user_orders, user_orders)
          |> assign(:changeset, changeset)
          |> assign(:store_slug, store_slug)
          |> assign(:page_title, "Review #{product.title}")
          |> render(:new)
        else
          conn
          |> put_flash(:error, "You must purchase this product before you can review it")
          |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
        end
      end
    end
  end

  def create(conn, %{"store_slug" => store_slug, "product_id" => product_id, "review" => review_params}) do
    user_id = conn.assigns.current_scope.user.id
    product_id = String.to_integer(product_id)
    
    # Verify user has purchased the product
    if Orders.user_purchased_product?(user_id, product_id) do
      # Generate immutable ID for the review
      review_attrs = Map.merge(review_params, %{
        "immutable_id" => Ecto.UUID.generate(),
        "user_id" => user_id,
        "product_id" => product_id
      })
      
      case Reviews.create_review(review_attrs) do
        {:ok, _review} ->
          conn
          |> put_flash(:info, "Review submitted successfully!")
          |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
      
        {:error, %Ecto.Changeset{} = changeset} ->
          product = Products.get_product_with_store!(product_id)
          user_orders = Orders.get_user_orders_with_product(user_id, product_id)
          
          conn
          |> assign(:product, product)
          |> assign(:user_orders, user_orders)
          |> assign(:changeset, changeset)
          |> assign(:store_slug, store_slug)
          |> assign(:page_title, "Review #{product.title}")
          |> render(:new)
      end
    else
      conn
      |> put_flash(:error, "You must purchase this product before you can review it")
                |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
    end
  end

  def index(conn, %{"store_slug" => store_slug, "product_id" => product_id}) do
    product_id = String.to_integer(product_id)
    product = Products.get_product_with_store!(product_id)
    
    # Verify the product belongs to the store with the given slug
    if product.store.slug != store_slug do
      conn
      |> put_flash(:error, "Product not found in this store")
      |> redirect(to: ~p"/stores/#{store_slug}")
    else
      # Get reviews for this product
      reviews = Reviews.get_product_reviews(product_id)
      average_rating = Reviews.get_product_average_rating(product_id)
      review_count = Reviews.get_product_review_count(product_id)
      rating_distribution = Reviews.get_product_rating_distribution(product_id)
      
      conn
      |> assign(:product, product)
      |> assign(:reviews, reviews)
      |> assign(:average_rating, average_rating)
      |> assign(:review_count, review_count)
      |> assign(:rating_distribution, rating_distribution)
      |> assign(:page_title, "Reviews for #{product.title}")
      |> render(:index)
    end
  end

  def edit(conn, %{"store_slug" => store_slug, "product_id" => product_id, "id" => review_id}) do
    user_id = conn.assigns.current_scope.user.id
    product_id = String.to_integer(product_id)
    review = Reviews.get_review!(String.to_integer(review_id))
    
    # Verify the review belongs to the current user
    if review.user_id != user_id do
      conn
      |> put_flash(:error, "You can only edit your own reviews")
                |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
    else
      # Verify the product belongs to the store with the given slug
      product = Products.get_product_with_store!(product_id)
      if product.store.slug != store_slug do
        conn
        |> put_flash(:error, "Product not found in this store")
        |> redirect(to: ~p"/stores/#{store_slug}")
      else
        changeset = Reviews.change_review(review)
        
        conn
        |> assign(:review, review)
        |> assign(:product, product)
        |> assign(:changeset, changeset)
        |> assign(:page_title, "Edit Review for #{product.title}")
        |> render(:edit)
      end
    end
  end

  def update(conn, %{"store_slug" => store_slug, "product_id" => product_id, "id" => review_id, "review" => review_params}) do
    user_id = conn.assigns.current_scope.user.id
    product_id = String.to_integer(product_id)
    review = Reviews.get_review!(String.to_integer(review_id))
    
    # Verify the review belongs to the current user
    if review.user_id != user_id do
      conn
      |> put_flash(:error, "You can only edit your own reviews")
                |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
    else
      case Reviews.update_review(review, review_params) do
        {:ok, _review} ->
          conn
          |> put_flash(:info, "Review updated successfully!")
          |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
        
        {:error, %Ecto.Changeset{} = changeset} ->
          product = Products.get_product_with_store!(product_id)
          
          conn
          |> assign(:review, review)
          |> assign(:product, product)
          |> assign(:changeset, changeset)
          |> assign(:page_title, "Edit Review for #{product.title}")
          |> render(:edit)
      end
    end
  end

  def delete(conn, %{"store_slug" => store_slug, "product_id" => product_id, "id" => review_id}) do
    user_id = conn.assigns.current_scope.user.id
    product_id = String.to_integer(product_id)
    review = Reviews.get_review!(String.to_integer(review_id))
    
    # Verify the review belongs to the current user
    if review.user_id != user_id do
      conn
      |> put_flash(:error, "You can only delete your own reviews")
                |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
    else
      case Reviews.delete_review(review) do
        {:ok, _review} ->
          conn
          |> put_flash(:info, "Review deleted successfully!")
          |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
        
        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Failed to delete review")
          |> redirect(to: ~p"/stores/#{store_slug}/products/#{product_id}")
      end
    end
  end

  def vote(conn, %{"review_id" => review_id, "helpful" => helpful}) do
    user_id = conn.assigns.current_scope.user.id
    helpful_bool = helpful == "true"
    
    case Reviews.get_or_create_review_vote(user_id, String.to_integer(review_id), helpful_bool) do
      {:ok, review_vote} ->
        # Update the review's helpful count
        review = Reviews.get_review!(String.to_integer(review_id))
        Reviews.update_review_helpful_count(review)
        
        conn
        |> json(%{success: true, helpful: review_vote.helpful})
      
      {:ok, :removed} ->
        # Update the review's helpful count
        review = Reviews.get_review!(String.to_integer(review_id))
        Reviews.update_review_helpful_count(review)
        
        conn
        |> json(%{success: true, helpful: nil})
      
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, errors: changeset.errors})
    end
  end
end
