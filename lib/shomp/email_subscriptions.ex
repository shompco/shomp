defmodule Shomp.EmailSubscriptions do
  @moduledoc """
  The EmailSubscriptions context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.EmailSubscriptions.EmailSubscription

  @doc """
  Returns the list of email subscriptions with pagination.
  """
  def list_email_subscriptions(page \\ 1, per_page \\ 50) do
    EmailSubscription
    |> order_by([e], [desc: e.subscribed_at])
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
  end

  @doc """
  Gets a single email subscription.
  """
  def get_email_subscription!(id), do: Repo.get!(EmailSubscription, id)

  @doc """
  Gets a single email subscription by email.
  """
  def get_email_subscription_by_email(email) do
    Repo.get_by(EmailSubscription, email: email)
  end

  @doc """
  Creates an email subscription.
  """
  def create_email_subscription(attrs \\ %{}) do
    attrs = Map.merge(attrs, %{
      subscribed_at: DateTime.utc_now(),
      status: "active"
    })
    
    %EmailSubscription{}
    |> EmailSubscription.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an email subscription.
  """
  def update_email_subscription(%EmailSubscription{} = email_subscription, attrs) do
    email_subscription
    |> EmailSubscription.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Unsubscribes an email subscription.
  """
  def unsubscribe_email_subscription(%EmailSubscription{} = email_subscription) do
    email_subscription
    |> EmailSubscription.unsubscribe_changeset()
    |> Repo.update()
  end

  @doc """
  Deletes an email subscription.
  """
  def delete_email_subscription(%EmailSubscription{} = email_subscription) do
    Repo.delete(email_subscription)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking email subscription changes.
  """
  def change_email_subscription(%EmailSubscription{} = email_subscription, attrs \\ %{}) do
    EmailSubscription.changeset(email_subscription, attrs)
  end

  @doc """
  Gets the total count of email subscriptions.
  """
  def count_email_subscriptions do
    Repo.aggregate(EmailSubscription, :count, :id)
  end

  @doc """
  Gets the count of active email subscriptions.
  """
  def count_active_subscriptions do
    EmailSubscription
    |> where([e], e.status == "active")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets email subscriptions by status.
  """
  def get_subscriptions_by_status(status) do
    EmailSubscription
    |> where([e], e.status == ^status)
    |> order_by([e], [desc: e.subscribed_at])
    |> Repo.all()
  end

  @doc """
  Gets email subscriptions by source.
  """
  def get_subscriptions_by_source(source) do
    EmailSubscription
    |> where([e], e.source == ^source)
    |> order_by([e], [desc: e.subscribed_at])
    |> Repo.all()
  end

  @doc """
  Searches email subscriptions by email.
  """
  def search_subscriptions_by_email(email_query) do
    EmailSubscription
    |> where([e], ilike(e.email, ^"%#{email_query}%"))
    |> order_by([e], [desc: e.subscribed_at])
    |> Repo.all()
  end
end
