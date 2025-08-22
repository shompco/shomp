defmodule Shomp.Reviews.Review do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Accounts.User
  alias Shomp.Products.Product
  alias Shomp.Orders.Order
  alias Shomp.Reviews.ReviewVote

  schema "reviews" do
    field :immutable_id, :string
    field :rating, :integer
    field :review_text, :string
    field :helpful_count, :integer, default: 0
    field :verified_purchase, :boolean, default: false
    
    belongs_to :product, Product
    belongs_to :user, User
    belongs_to :order, Order
    
    has_many :votes, ReviewVote
    has_many :user_votes, through: [:votes, :user]

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating reviews.
  """
  def create_changeset(review, attrs) do
    review
    |> cast(attrs, [:immutable_id, :rating, :review_text, :product_id, :user_id, :order_id])
    |> validate_required([:immutable_id, :rating, :product_id, :user_id, :order_id])
    |> validate_number(:rating, greater_than: 0, less_than_or_equal_to: 5)
    |> validate_length(:review_text, max: 2000)
    |> unique_constraint(:immutable_id)
    |> unique_constraint([:user_id, :product_id], name: :user_can_only_review_once_per_product)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:order_id)
    |> put_change(:verified_purchase, true) # All reviews come from verified purchases
  end

  @doc """
  A changeset for updating reviews.
  """
  def update_changeset(review, attrs) do
    review
    |> cast(attrs, [:rating, :review_text])
    |> validate_number(:rating, greater_than: 0, less_than_or_equal_to: 5)
    |> validate_length(:review_text, max: 2000)
  end

  @doc """
  A changeset for updating helpful count.
  """
  def helpful_count_changeset(review, helpful_count) do
    review
    |> cast(%{helpful_count: helpful_count}, [:helpful_count])
    |> validate_number(:helpful_count, greater_than_or_equal_to: 0)
  end
end
