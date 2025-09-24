defmodule Shomp.NotificationPreferences do
  @moduledoc """
  The NotificationPreferences context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.NotificationPreferences.NotificationPreference

  @doc """
  Returns the notification preferences for a user.
  Creates default preferences if none exist.
  """
  def get_user_preferences(user_id) do
    case Repo.get_by(NotificationPreference, user_id: user_id) do
      nil -> create_default_preferences(user_id)
      preferences -> {:ok, preferences}
    end
  end

  @doc """
  Gets a single notification preference.
  """
  def get_notification_preference!(id), do: Repo.get!(NotificationPreference, id)

  @doc """
  Creates default notification preferences for a user.
  """
  def create_default_preferences(user_id) do
    attrs = %{user_id: user_id}

    case %NotificationPreference{}
         |> NotificationPreference.changeset(attrs)
         |> Repo.insert() do
      {:ok, preferences} -> {:ok, preferences}
      error -> error
    end
  end

  @doc """
  Creates notification preferences.
  """
  def create_notification_preference(attrs \\ %{}) do
    %NotificationPreference{}
    |> NotificationPreference.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates notification preferences.
  """
  def update_notification_preference(%NotificationPreference{} = preferences, attrs) do
    preferences
    |> NotificationPreference.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes notification preferences.
  """
  def delete_notification_preference(%NotificationPreference{} = preferences) do
    Repo.delete(preferences)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification preference changes.
  """
  def change_notification_preference(%NotificationPreference{} = preferences, attrs \\ %{}) do
    NotificationPreference.changeset(preferences, attrs)
  end

  @doc """
  Checks if a user wants to receive a specific notification type via email.
  """
  def wants_email_notification?(user_id, notification_type) do
    case get_user_preferences(user_id) do
      {:ok, preferences} ->
        case notification_type do
          :you_sold_something -> preferences.email_you_sold_something
          :shipping_label_created -> preferences.email_shipping_label_created
          :purchase_shipped -> preferences.email_purchase_shipped
          :purchase_delivered -> preferences.email_purchase_delivered
          :leave_review_reminder -> preferences.email_leave_review_reminder
          _ -> false
        end
      _ -> false
    end
  end

  @doc """
  Checks if a user wants to receive a specific notification type via SMS.
  """
  def wants_sms_notification?(user_id, notification_type) do
    case get_user_preferences(user_id) do
      {:ok, preferences} ->
        case notification_type do
          :you_sold_something -> preferences.sms_you_sold_something
          :shipping_label_created -> preferences.sms_shipping_label_created
          :purchase_shipped -> preferences.sms_purchase_shipped
          :purchase_delivered -> preferences.sms_purchase_delivered
          :leave_review_reminder -> preferences.sms_leave_review_reminder
          _ -> false
        end
      _ -> false
    end
  end
end
