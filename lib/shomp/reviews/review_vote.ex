defmodule Shomp.Reviews.ReviewVote do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Accounts.User
  alias Shomp.Reviews.Review

  schema "review_votes" do
    field :helpful, :boolean
    
    belongs_to :review, Review
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating review votes.
  """
  def create_changeset(review_vote, attrs) do
    review_vote
    |> cast(attrs, [:helpful, :review_id, :user_id])
    |> validate_required([:helpful, :review_id, :user_id])
    |> unique_constraint([:user_id, :review_id], name: :user_can_only_vote_once_per_review)
    |> foreign_key_constraint(:review_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  A changeset for updating review votes.
  """
  def update_changeset(review_vote, attrs) do
    review_vote
    |> cast(attrs, [:helpful])
    |> validate_required([:helpful])
  end
end
