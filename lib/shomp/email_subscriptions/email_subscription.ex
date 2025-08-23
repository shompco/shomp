defmodule Shomp.EmailSubscriptions.EmailSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "email_subscriptions" do
    field :email, :string
    field :source, :string, default: "landing_page"
    field :subscribed_at, :utc_datetime
    field :unsubscribed_at, :utc_datetime
    field :status, :string, default: "active"
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(email_subscription, attrs) do
    email_subscription
    |> cast(attrs, [:email, :source, :subscribed_at, :unsubscribed_at, :status, :metadata])
    |> validate_required([:email, :subscribed_at])
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:status, ["active", "unsubscribed", "bounced"])
    |> unique_constraint(:email)
  end



  def unsubscribe_changeset(email_subscription) do
    email_subscription
    |> changeset(%{
      unsubscribed_at: DateTime.utc_now(),
      status: "unsubscribed"
    })
  end
end
