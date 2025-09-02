defmodule Shomp.Stores.StoreKYC do
  use Ecto.Schema
  import Ecto.Changeset

  schema "store_kyc" do
    field :legal_name, :string
    field :business_type, :string # individual, llc, corporation, etc.
    field :tax_id, :string # EIN or SSN
    field :address_line_1, :string
    field :address_line_2, :string
    field :city, :string
    field :state, :string
    field :zip_code, :string
    field :country, :string, default: "US"
    field :phone, :string
    field :email, :string
    
    # Document verification
    field :id_document_path, :string # Driver's license, passport, etc.
    field :business_license_path, :string # If applicable
    field :tax_document_path, :string # W9 or similar
    
    # Status fields
    field :status, :string, default: "pending" # pending, submitted, verified, rejected
    field :submitted_at, :utc_datetime
    field :verified_at, :utc_datetime
    field :rejected_at, :utc_datetime
    field :rejection_reason, :string
    
    # Admin notes
    field :admin_notes, :string
    
    # Stripe Connect fields
    field :stripe_account_id, :string
    field :charges_enabled, :boolean, default: false
    field :payouts_enabled, :boolean, default: false
    field :requirements, :map, default: %{}
    field :onboarding_completed, :boolean, default: false
    field :stripe_individual_info, :map, default: %{}
    
    belongs_to :store, Shomp.Stores.Store
    field :store_data, :map, virtual: true  # Virtual field to hold store data
    
    timestamps()
  end

  @doc false
  def changeset(store_kyc, attrs) do
    store_kyc
    |> cast(attrs, [:legal_name, :business_type, :tax_id, :address_line_1, :address_line_2, :city, :state, :zip_code, :country, :phone, :email, :id_document_path, :business_license_path, :tax_document_path, :status, :submitted_at, :verified_at, :rejected_at, :rejection_reason, :admin_notes, :store_id, :stripe_account_id, :charges_enabled, :payouts_enabled, :requirements, :onboarding_completed, :stripe_individual_info])
    |> validate_required([:store_id])
    |> validate_inclusion(:status, ["pending", "submitted", "verified", "rejected"])
    |> validate_inclusion(:business_type, ["individual", "llc", "corporation", "partnership", "sole_proprietorship"])
    |> validate_inclusion(:country, ["US"])
    |> validate_format(:email, ~r/@/, message: "must be a valid email address")
    |> validate_format(:tax_id, ~r/^\d{9}$|^\d{3}-\d{2}-\d{4}$/, message: "must be a valid EIN (XX-XXXXXXX) or SSN (XXX-XX-XXXX)")
    |> validate_format(:zip_code, ~r/^\d{5}(-\d{4})?$/, message: "must be a valid US ZIP code")
    |> foreign_key_constraint(:store_id)
  end

  @doc """
  Creates a changeset for creating a minimal KYC record for Stripe Connect.
  """
  def minimal_changeset(store_kyc, attrs) do
    store_kyc
    |> cast(attrs, [:store_id, :stripe_account_id, :charges_enabled, :payouts_enabled, :requirements, :onboarding_completed])
    |> validate_required([:store_id])
    |> validate_inclusion(:charges_enabled, [true, false])
    |> validate_inclusion(:payouts_enabled, [true, false])
    |> validate_inclusion(:onboarding_completed, [true, false])
    |> foreign_key_constraint(:store_id)
  end

  @doc """
  Creates a changeset for submitting KYC documents.
  """
  def submit_changeset(store_kyc, attrs) do
    store_kyc
    |> changeset(attrs)
    |> put_change(:status, "submitted")
    |> put_change(:submitted_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Creates a changeset for verifying KYC.
  """
  def verify_changeset(store_kyc) do
    store_kyc
    |> change(%{
      status: "verified",
      verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Creates a changeset for rejecting KYC.
  """
  def reject_changeset(store_kyc, reason) do
    store_kyc
    |> change(%{
      status: "rejected",
      rejected_at: DateTime.utc_now() |> DateTime.truncate(:second),
      rejection_reason: reason
    })
  end

  @doc """
  Checks if KYC is verified.
  """
  def verified?(store_kyc) do
    store_kyc.status == "verified"
  end

  @doc """
  Checks if KYC is pending or submitted.
  """
  def pending?(store_kyc) do
    store_kyc.status in ["pending", "submitted"]
  end

  @doc """
  Checks if KYC was rejected.
  """
  def rejected?(store_kyc) do
    store_kyc.status == "rejected"
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
