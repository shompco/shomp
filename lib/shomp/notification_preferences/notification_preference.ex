defmodule Shomp.NotificationPreferences.NotificationPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification_preferences" do
    belongs_to :user, Shomp.Accounts.User

    # Email preferences
    field :email_you_sold_something, :boolean, default: true
    field :email_shipping_label_created, :boolean, default: true
    field :email_purchase_shipped, :boolean, default: true
    field :email_purchase_delivered, :boolean, default: true
    field :email_leave_review_reminder, :boolean, default: true

    # SMS preferences
    field :sms_you_sold_something, :boolean, default: false
    field :sms_shipping_label_created, :boolean, default: false
    field :sms_purchase_shipped, :boolean, default: false
    field :sms_purchase_delivered, :boolean, default: false
    field :sms_leave_review_reminder, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :user_id,
      :email_you_sold_something, :email_shipping_label_created, :email_purchase_shipped,
      :email_purchase_delivered, :email_leave_review_reminder,
      :sms_you_sold_something, :sms_shipping_label_created, :sms_purchase_shipped,
      :sms_purchase_delivered, :sms_leave_review_reminder
    ])
    |> validate_required([:user_id])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id)
  end
end
