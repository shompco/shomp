defmodule Shomp.EmailPreferences.EmailPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "email_preferences" do
    # Order notifications
    field :order_confirmation, :boolean, default: true
    field :order_status_updates, :boolean, default: true
    field :shipping_notifications, :boolean, default: true
    field :delivery_confirmation, :boolean, default: true
    
    # Support notifications
    field :support_ticket_updates, :boolean, default: true
    field :support_ticket_resolved, :boolean, default: true
    
    # Marketing notifications
    field :product_updates, :boolean, default: false
    field :promotional_emails, :boolean, default: false
    field :newsletter, :boolean, default: false
    
    # System notifications
    field :security_alerts, :boolean, default: true
    field :account_updates, :boolean, default: true
    field :system_maintenance, :boolean, default: true

    belongs_to :user, Shomp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :user_id, :order_confirmation, :order_status_updates, :shipping_notifications, 
      :delivery_confirmation, :support_ticket_updates, :support_ticket_resolved,
      :product_updates, :promotional_emails, :newsletter, :security_alerts,
      :account_updates, :system_maintenance
    ])
    |> validate_required([:user_id])
    |> foreign_key_constraint(:user_id)
  end
end
