defmodule Shomp.Repo.Migrations.CreateNotificationPreferences do
  use Ecto.Migration

  def change do
    create table(:notification_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      # Email preferences
      add :email_you_sold_something, :boolean, default: true
      add :email_shipping_label_created, :boolean, default: true
      add :email_purchase_shipped, :boolean, default: true
      add :email_purchase_delivered, :boolean, default: true
      add :email_leave_review_reminder, :boolean, default: true

      # SMS preferences
      add :sms_you_sold_something, :boolean, default: false
      add :sms_shipping_label_created, :boolean, default: false
      add :sms_purchase_shipped, :boolean, default: false
      add :sms_purchase_delivered, :boolean, default: false
      add :sms_leave_review_reminder, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:notification_preferences, [:user_id])
  end
end
