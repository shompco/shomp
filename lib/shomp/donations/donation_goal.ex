defmodule Shomp.Donations.DonationGoal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "donation_goals" do
    field :title, :string
    field :description, :string
    field :target_amount, :decimal
    field :current_amount, :decimal
    field :status, :string, default: "active"

    has_many :donations, Shomp.Donations.Donation

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(donation_goal, attrs) do
    donation_goal
    |> cast(attrs, [:title, :description, :target_amount, :current_amount, :status])
    |> validate_required([:title, :description, :target_amount])
    |> validate_number(:target_amount, greater_than: 0)
    |> validate_number(:current_amount, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, ["active", "completed", "paused"])
  end
end
