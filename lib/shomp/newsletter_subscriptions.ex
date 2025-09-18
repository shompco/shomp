defmodule Shomp.NewsletterSubscriptions do
  @moduledoc """
  The NewsletterSubscriptions context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.NewsletterSubscriptions.NewsletterSubscription

  @doc """
  Returns the list of newsletter_subscriptions.

  ## Examples

      iex> list_newsletter_subscriptions()
      [%NewsletterSubscription{}, ...]

  """
  def list_newsletter_subscriptions do
    Repo.all(NewsletterSubscription)
  end

  @doc """
  Gets a single newsletter_subscription.

  Raises `Ecto.NoResultsError` if the Newsletter subscription does not exist.

  ## Examples

      iex> get_newsletter_subscription!(123)
      %NewsletterSubscription{}

      iex> get_newsletter_subscription!(456)
      ** (Ecto.NoResultsError)

  """
  def get_newsletter_subscription!(id), do: Repo.get!(NewsletterSubscription, id)

  @doc """
  Gets a newsletter subscription by email.

  ## Examples

      iex> get_newsletter_subscription_by_email("user@example.com")
      %NewsletterSubscription{}

      iex> get_newsletter_subscription_by_email("nonexistent@example.com")
      nil

  """
  def get_newsletter_subscription_by_email(email) do
    Repo.get_by(NewsletterSubscription, email: email)
  end

  @doc """
  Creates a newsletter_subscription.

  ## Examples

      iex> create_newsletter_subscription(%{field: value})
      {:ok, %NewsletterSubscription{}}

      iex> create_newsletter_subscription(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_newsletter_subscription(attrs \\ %{}) do
    %NewsletterSubscription{}
    |> NewsletterSubscription.subscribe_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a newsletter_subscription.

  ## Examples

      iex> update_newsletter_subscription(newsletter_subscription, %{field: new_value})
      {:ok, %NewsletterSubscription{}}

      iex> update_newsletter_subscription(newsletter_subscription, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_newsletter_subscription(%NewsletterSubscription{} = newsletter_subscription, attrs) do
    newsletter_subscription
    |> NewsletterSubscription.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a newsletter_subscription.

  ## Examples

      iex> delete_newsletter_subscription(newsletter_subscription)
      {:ok, %NewsletterSubscription{}}

      iex> delete_newsletter_subscription(newsletter_subscription)
      {:error, %Ecto.Changeset{}}

  """
  def delete_newsletter_subscription(%NewsletterSubscription{} = newsletter_subscription) do
    Repo.delete(newsletter_subscription)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking newsletter_subscription changes.

  ## Examples

      iex> change_newsletter_subscription(newsletter_subscription)
      %Ecto.Changeset{data: %NewsletterSubscription{}}

  """
  def change_newsletter_subscription(%NewsletterSubscription{} = newsletter_subscription, attrs \\ %{}) do
    NewsletterSubscription.changeset(newsletter_subscription, attrs)
  end

  @doc """
  Subscribes an email to the newsletter.

  ## Examples

      iex> subscribe_to_newsletter("user@example.com")
      {:ok, %NewsletterSubscription{}}

      iex> subscribe_to_newsletter("invalid-email")
      {:error, %Ecto.Changeset{}}

  """
  def subscribe_to_newsletter(email, opts \\ []) do
    source = Keyword.get(opts, :source, "website")
    metadata = Keyword.get(opts, :metadata, %{})
    beehiiv_subscriber_id = Keyword.get(opts, :beehiiv_subscriber_id)

    attrs = %{
      email: email,
      source: source,
      metadata: metadata,
      beehiiv_subscriber_id: beehiiv_subscriber_id
    }

    case get_newsletter_subscription_by_email(email) do
      nil ->
        create_newsletter_subscription(attrs)
      existing_subscription ->
        if existing_subscription.status == "unsubscribed" do
          # Resubscribe
          existing_subscription
          |> NewsletterSubscription.subscribe_changeset(attrs)
          |> Repo.update()
        else
          # Already subscribed
          {:ok, existing_subscription}
        end
    end
  end

  @doc """
  Unsubscribes an email from the newsletter.

  ## Examples

      iex> unsubscribe_from_newsletter("user@example.com")
      {:ok, %NewsletterSubscription{}}

      iex> unsubscribe_from_newsletter("nonexistent@example.com")
      {:error, :not_found}

  """
  def unsubscribe_from_newsletter(email) do
    case get_newsletter_subscription_by_email(email) do
      nil ->
        {:error, :not_found}
      subscription ->
        subscription
        |> NewsletterSubscription.unsubscribe_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Gets active newsletter subscriptions.

  ## Examples

      iex> list_active_subscriptions()
      [%NewsletterSubscription{}, ...]

  """
  def list_active_subscriptions do
    NewsletterSubscription
    |> where([n], n.status == "active")
    |> order_by([n], desc: n.subscribed_at)
    |> Repo.all()
  end

  @doc """
  Gets newsletter subscription statistics.

  ## Examples

      iex> get_subscription_stats()
      %{total: 100, active: 95, unsubscribed: 5}

  """
  def get_subscription_stats do
    total = Repo.aggregate(NewsletterSubscription, :count, :id)
    active = Repo.aggregate(from(n in NewsletterSubscription, where: n.status == "active"), :count, :id)
    unsubscribed = Repo.aggregate(from(n in NewsletterSubscription, where: n.status == "unsubscribed"), :count, :id)

    %{
      total: total,
      active: active,
      unsubscribed: unsubscribed
    }
  end
end
