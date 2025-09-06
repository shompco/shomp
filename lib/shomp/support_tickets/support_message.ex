defmodule Shomp.SupportTickets.SupportMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "support_messages" do
    field :message, :string
    field :is_internal, :boolean, default: false
    field :is_from_admin, :boolean, default: false
    field :attachments, :map, default: %{}

    belongs_to :support_ticket, Shomp.SupportTickets.SupportTicket
    belongs_to :author_user, Shomp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:message, :is_internal, :is_from_admin, :author_user_id, :support_ticket_id, :attachments])
    |> validate_required([:message, :author_user_id, :support_ticket_id])
    |> foreign_key_constraint(:author_user_id)
    |> foreign_key_constraint(:support_ticket_id)
  end
end
