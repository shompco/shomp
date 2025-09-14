defmodule Shomp.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :immutable_id, :string
    field :title, :string
    field :message, :string
    field :type, :string
    field :read, :boolean, default: false
    field :action_url, :string
    field :metadata, :map, default: %{}
    field :priority, :string, default: "normal" # low, normal, high, urgent

    belongs_to :user, Shomp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:immutable_id, :user_id, :title, :message, :type, :read, :action_url, :metadata, :priority])
    |> validate_required([:user_id, :title, :message, :type])
    |> validate_inclusion(:type, [
      "order_update", "purchase", "kyc_complete", "store_created", "product_added",
      "feature_request", "donation", "support_request", "payment_received",
      "order_shipped", "order_delivered", "refund_processed", "new_order",
      "store_balance_update", "payout_notification", "product_approved",
      "product_flagged", "system_maintenance", "security_alert"
    ])
    |> validate_inclusion(:priority, ["low", "normal", "high", "urgent"])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:immutable_id)
  end

  @doc """
  A changeset for creating notifications with auto-generated immutable_id.
  """
  def create_changeset(notification, attrs) do
    attrs_with_id = Map.put_new(attrs, :immutable_id, Ecto.UUID.generate())

    notification
    |> changeset(attrs_with_id)
    |> validate_required([:immutable_id])
  end
end
