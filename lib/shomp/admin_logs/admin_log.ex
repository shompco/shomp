defmodule Shomp.AdminLogs.AdminLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_logs" do
    field :admin_user_id, :integer
    field :entity_type, :string
    field :entity_id, :integer
    field :action, :string
    field :details, :string
    field :metadata, :map

    timestamps()
  end

  @doc false
  def changeset(admin_log, attrs) do
    admin_log
    |> cast(attrs, [:admin_user_id, :entity_type, :entity_id, :action, :details, :metadata])
    |> validate_required([:admin_user_id, :entity_type, :entity_id, :action, :details])
    |> validate_inclusion(:entity_type, ["product", "store", "user", "category", "order"])
    |> validate_inclusion(:action, ["create", "edit", "delete", "approve", "reject", "suspend"])
  end
end
