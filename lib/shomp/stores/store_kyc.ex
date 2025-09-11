defmodule Shomp.Stores.StoreKYC do
  use Ecto.Schema
  import Ecto.Changeset

  schema "store_kyc" do
    # Stripe Connect fields only
    field :stripe_account_id, :string
    field :charges_enabled, :boolean, default: false
    field :payouts_enabled, :boolean, default: false
    field :requirements, :map, default: %{}
    field :onboarding_completed, :boolean, default: false
    field :stripe_individual_info, :map, default: %{}
    field :stripe_country, :string

    belongs_to :store, Shomp.Stores.Store
    field :store_data, :map, virtual: true  # Virtual field to hold store data

    timestamps()
  end

  @doc false
  def changeset(store_kyc, attrs) do
    store_kyc
    |> cast(attrs, [:store_id, :stripe_account_id, :charges_enabled, :payouts_enabled, :requirements, :onboarding_completed, :stripe_individual_info, :stripe_country])
    |> validate_required([:store_id])
    |> validate_inclusion(:charges_enabled, [true, false])
    |> validate_inclusion(:payouts_enabled, [true, false])
    |> validate_inclusion(:onboarding_completed, [true, false])
    |> foreign_key_constraint(:store_id)
  end

  @doc """
  Creates a changeset for creating a minimal KYC record for Stripe Connect.
  """
  def minimal_changeset(store_kyc, attrs) do
    store_kyc
    |> cast(attrs, [:store_id, :stripe_account_id, :charges_enabled, :payouts_enabled, :requirements, :onboarding_completed, :stripe_country])
    |> validate_required([:store_id])
    |> validate_inclusion(:charges_enabled, [true, false])
    |> validate_inclusion(:payouts_enabled, [true, false])
    |> validate_inclusion(:onboarding_completed, [true, false])
    |> foreign_key_constraint(:store_id)
  end

  @doc """
  Checks if Stripe Connect account is fully verified.
  """
  def stripe_verified?(store_kyc) do
    store_kyc.charges_enabled && store_kyc.payouts_enabled && store_kyc.onboarding_completed
  end

  @doc """
  Checks if Stripe Connect onboarding has been started.
  """
  def stripe_onboarding_started?(store_kyc) do
    not is_nil(store_kyc.stripe_account_id)
  end

  @doc """
  Checks if Stripe Connect onboarding is completed.
  """
  def stripe_onboarding_completed?(store_kyc) do
    store_kyc.onboarding_completed
  end
end
