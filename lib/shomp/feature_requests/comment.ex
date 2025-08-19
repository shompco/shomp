defmodule Shomp.FeatureRequests.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :content, :string
    field :created_at, :utc_datetime
    
    belongs_to :request, Shomp.FeatureRequests.Request
    belongs_to :user, Shomp.Accounts.User
    
    timestamps()
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:content, :request_id, :user_id])
    |> validate_required([:content, :request_id, :user_id])
    |> validate_length(:content, min: 1, max: 1000)
    |> foreign_key_constraint(:request_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a changeset for a new comment.
  """
  def create_changeset(comment, attrs, user_id) do
    comment
    |> changeset(attrs)
    |> put_change(:user_id, user_id)
    |> put_change(:created_at, DateTime.utc_now())
  end
end
