defmodule Shomp.FeatureRequests.Request do
  use Ecto.Schema
  import Ecto.Changeset

  schema "requests" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "open"
    field :priority, :integer, default: 0
    
    belongs_to :user, Shomp.Accounts.User
    has_many :votes, Shomp.FeatureRequests.Vote
    has_many :comments, Shomp.FeatureRequests.Comment
    
    timestamps()
  end

  @doc false
  def changeset(request, attrs) do
    request
    |> cast(attrs, [:title, :description, :status, :priority])
    |> validate_required([:title, :description])
    |> validate_inclusion(:status, ["open", "in_progress", "completed", "declined"])
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a changeset for a new feature request.
  """
  def create_changeset(request, attrs, user_id) do
    request
    |> changeset(attrs)
    |> put_change(:user_id, user_id)
  end
end
