defmodule Shomp.Reviews do
  @moduledoc """
  The Reviews context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Reviews.{Review, ReviewVote}

  @doc """
  Returns the list of reviews.
  """
  def list_reviews do
    Repo.all(Review)
  end

  @doc """
  Gets a single review.
  """
  def get_review!(id), do: Repo.get!(Review, id)

  @doc """
  Gets a single review by immutable_id.
  """
  def get_review_by_immutable_id!(immutable_id), do: Repo.get_by!(Review, immutable_id: immutable_id)

  @doc """
  Creates a review.
  """
  def create_review(attrs \\ %{}) do
    %Review{}
    |> Review.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a review.
  """
  def update_review(%Review{} = review, attrs) do
    review
    |> Review.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a review.
  """
  def delete_review(%Review{} = review) do
    Repo.delete(review)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking review changes.
  """
  def change_review(%Review{} = review, attrs \\ %{}) do
    Review.create_changeset(review, attrs)
  end

  @doc """
  Gets reviews for a specific product.
  """
  def get_product_reviews(product_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    Review
    |> where([r], r.product_id == ^product_id)
    |> preload([:user, :votes])
    |> order_by([r], [{^sort_order, ^sort_by}])
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Gets reviews submitted by a specific user.
  """
  def get_user_reviews(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    Review
    |> where([r], r.user_id == ^user_id)
    |> preload([:product, :votes])
    |> order_by([r], [desc: r.inserted_at])
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Checks if a user has already reviewed a specific product.
  """
  def user_has_reviewed_product?(user_id, product_id) do
    Review
    |> where([r], r.user_id == ^user_id and r.product_id == ^product_id)
    |> Repo.exists?()
  end

  @doc """
  Gets the average rating for a product.
  """
  def get_product_average_rating(product_id) do
    Review
    |> where([r], r.product_id == ^product_id)
    |> select([r], avg(r.rating))
    |> Repo.one()
    |> case do
      %Decimal{} = avg -> Decimal.round(avg, 1)
      nil -> nil
    end
  end

  @doc """
  Gets the total review count for a product.
  """
  def get_product_review_count(product_id) do
    Review
    |> where([r], r.product_id == ^product_id)
    |> select([r], count(r.id))
    |> Repo.one()
  end

  @doc """
  Gets rating distribution for a product (how many 1-star, 2-star, etc.).
  """
  def get_product_rating_distribution(product_id) do
    Review
    |> where([r], r.product_id == ^product_id)
    |> group_by([r], r.rating)
    |> select([r], {r.rating, count(r.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  # ReviewVote functions

  @doc """
  Creates a review vote.
  """
  def create_review_vote(attrs \\ %{}) do
    %ReviewVote{}
    |> ReviewVote.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a review vote.
  """
  def update_review_vote(%ReviewVote{} = review_vote, attrs) do
    review_vote
    |> ReviewVote.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets or creates a review vote for a user and review.
  """
  def get_or_create_review_vote(user_id, review_id, helpful) do
    case Repo.get_by(ReviewVote, user_id: user_id, review_id: review_id) do
      nil ->
        create_review_vote(%{
          user_id: user_id,
          review_id: review_id,
          helpful: helpful
        })

      existing_vote ->
        if existing_vote.helpful == helpful do
          # User is trying to vote the same way, remove the vote
          Repo.delete(existing_vote)
          {:ok, :removed}
        else
          # User is changing their vote
          update_review_vote(existing_vote, %{helpful: helpful})
        end
    end
  end

  @doc """
  Gets the vote count for a review.
  """
  def get_review_vote_count(review_id) do
    ReviewVote
    |> where([rv], rv.review_id == ^review_id and rv.helpful == true)
    |> select([rv], count(rv.id))
    |> Repo.one()
  end

  @doc """
  Updates the helpful count for a review.
  """
  def update_review_helpful_count(%Review{} = review) do
    helpful_count = get_review_vote_count(review.id)
    
    review
    |> Review.helpful_count_changeset(helpful_count)
    |> Repo.update()
  end

  @doc """
  Checks if a user has voted on a specific review.
  """
  def user_has_voted_on_review?(user_id, review_id) do
    ReviewVote
    |> where([rv], rv.user_id == ^user_id and rv.review_id == ^review_id)
    |> Repo.exists?()
  end

  @doc """
  Gets a user's vote on a specific review.
  """
  def get_user_vote_on_review(user_id, review_id) do
    Repo.get_by(ReviewVote, user_id: user_id, review_id: review_id)
  end
end
