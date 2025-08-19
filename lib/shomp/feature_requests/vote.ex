defmodule Shomp.FeatureRequests.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "votes" do
    field :weight, :integer, default: 1
    
    belongs_to :request, Shomp.FeatureRequests.Request
    belongs_to :user, Shomp.Accounts.User
    
    timestamps()
  end

  @doc false
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:weight, :request_id, :user_id])
    |> validate_required([:weight, :request_id, :user_id])
    |> validate_number(:weight, greater_than_or_equal_to: -1, less_than_or_equal_to: 1)
    |> foreign_key_constraint(:request_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:request_id, :user_id], name: :votes_request_id_user_id_index)
  end

  @doc """
  Creates a changeset for a new vote.
  """
  def create_changeset(vote, attrs, user_id) do
    attrs_with_user = Map.put(attrs, :user_id, user_id)
    vote
    |> changeset(attrs_with_user)
  end
end
