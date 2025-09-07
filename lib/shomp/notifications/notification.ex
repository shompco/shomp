defmodule Shomp.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :title, :string
    field :message, :string
    field :type, :string
    field :read, :boolean, default: false
    field :action_url, :string
    field :metadata, :map, default: %{}

    belongs_to :user, Shomp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :title, :message, :type, :read, :action_url, :metadata])
    |> validate_required([:user_id, :title, :message, :type])
    |> foreign_key_constraint(:user_id)
  end
end
