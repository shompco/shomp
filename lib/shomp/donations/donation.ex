defmodule Shomp.Donations.Donation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "donations" do
    field :amount, :decimal
    field :stripe_payment_intent_id, :string
    field :donor_name, :string
    field :donor_email, :string
    field :message, :string
    field :is_anonymous, :boolean, default: false
    field :is_public, :boolean, default: true
    field :status, :string, default: "completed"

    belongs_to :donation_goal, Shomp.Donations.DonationGoal, type: :binary_id
    belongs_to :user, Shomp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(donation, attrs) do
    donation
    |> cast(attrs, [
      :donation_goal_id, :user_id, :amount, :stripe_payment_intent_id,
      :donor_name, :donor_email, :message, :is_anonymous, :is_public, :status
    ])
    |> validate_required([:amount, :stripe_payment_intent_id])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:status, ["completed", "failed", "refunded"])
    |> validate_format(:donor_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
  end

  @doc """
  Gets the display name for a donation, respecting anonymity settings.
  """
  def display_name(%__MODULE__{is_anonymous: true}), do: "Anonymous"
  def display_name(%__MODULE__{donor_name: nil}), do: "Anonymous"
  def display_name(%__MODULE__{donor_name: name}), do: name

  @doc """
  Gets the initials for a donation, respecting anonymity settings.
  """
  def initials(%__MODULE__{is_anonymous: true}), do: "A"
  def initials(%__MODULE__{donor_name: nil}), do: "A"
  def initials(%__MODULE__{donor_name: name}) do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end
end
