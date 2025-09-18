defmodule Shomp.NewsletterSubscriptions.NewsletterSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "newsletter_subscriptions" do
    field :email, :string
    field :subscribed_at, :utc_datetime
    field :unsubscribed_at, :utc_datetime
    field :status, :string, default: "active"
    field :source, :string, default: "website"
    field :beehiiv_subscriber_id, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(newsletter_subscription, attrs) do
    newsletter_subscription
    |> cast(attrs, [:email, :subscribed_at, :unsubscribed_at, :status, :source, :beehiiv_subscriber_id, :metadata])
    |> validate_required([:email, :subscribed_at, :status])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email address")
    |> validate_inclusion(:status, ["active", "unsubscribed", "bounced", "complained"])
    |> validate_inclusion(:source, ["website", "admin", "api", "import"])
    |> unique_constraint(:email)
  end

  @doc false
  def subscribe_changeset(newsletter_subscription, attrs) do
    newsletter_subscription
    |> cast(attrs, [:email, :source, :metadata])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email address")
    |> put_change(:subscribed_at, DateTime.utc_now())
    |> put_change(:status, "active")
    |> put_change(:source, attrs[:source] || "website")
    |> unique_constraint(:email)
  end

  @doc false
  def unsubscribe_changeset(newsletter_subscription) do
    newsletter_subscription
    |> cast(%{}, [])
    |> put_change(:status, "unsubscribed")
    |> put_change(:unsubscribed_at, DateTime.utc_now())
  end
end
