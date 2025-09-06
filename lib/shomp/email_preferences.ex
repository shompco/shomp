defmodule Shomp.EmailPreferences do
  @moduledoc """
  The EmailPreferences context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.EmailPreferences.EmailPreference

  def get_user_preferences(user_id) do
    case Repo.get_by(EmailPreference, user_id: user_id) do
      nil -> create_default_preferences(user_id)
      preferences -> preferences
    end
  end

  def update_preferences(user_id, attrs) do
    preferences = get_user_preferences(user_id)
    
    preferences
    |> EmailPreference.changeset(attrs)
    |> Repo.update()
  end

  def can_send_email?(user_id, email_type) do
    preferences = get_user_preferences(user_id)
    Map.get(preferences, email_type, true)
  end

  defp create_default_preferences(user_id) do
    %EmailPreference{}
    |> EmailPreference.changeset(%{user_id: user_id})
    |> Repo.insert!()
  end
end
