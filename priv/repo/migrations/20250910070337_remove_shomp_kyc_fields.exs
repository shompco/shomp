defmodule Shomp.Repo.Migrations.RemoveShompKycFields do
  use Ecto.Migration

  def change do
    # Remove Shomp KYC fields from store_kyc table
    alter table(:store_kyc) do
      remove :legal_name, :string
      remove :business_type, :string
      remove :tax_id, :string
      remove :address_line_1, :string
      remove :address_line_2, :string
      remove :city, :string
      remove :state, :string
      remove :zip_code, :string
      remove :country, :string
      remove :phone, :string
      remove :email, :string
      remove :id_document_path, :string
      remove :business_license_path, :string
      remove :tax_document_path, :string
      remove :status, :string
      remove :submitted_at, :utc_datetime
      remove :verified_at, :utc_datetime
      remove :rejected_at, :utc_datetime
      remove :rejection_reason, :string
      remove :admin_notes, :string
    end

    # Remove Shomp KYC fields from store_balances table
    alter table(:store_balances) do
      remove :kyc_verified, :boolean
      remove :kyc_verified_at, :utc_datetime
      remove :kyc_documents_submitted, :boolean
      remove :kyc_submitted_at, :utc_datetime
    end

    # Drop indexes that are no longer needed (if they exist)
    execute "DROP INDEX IF EXISTS store_kyc_status_index"
    execute "DROP INDEX IF EXISTS store_balances_kyc_verified_index"
  end
end
