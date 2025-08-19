defmodule Shomp.Repo.Migrations.CreateStoreKyc do
  use Ecto.Migration

  def change do
    create table(:store_kyc) do
      add :legal_name, :string, null: false
      add :business_type, :string, null: false
      add :tax_id, :string, null: false
      add :address_line_1, :string, null: false
      add :address_line_2, :string
      add :city, :string, null: false
      add :state, :string, null: false
      add :zip_code, :string, null: false
      add :country, :string, default: "US", null: false
      add :phone, :string, null: false
      add :email, :string, null: false
      
      # Document verification
      add :id_document_path, :string
      add :business_license_path, :string
      add :tax_document_path, :string
      
      # Status fields
      add :status, :string, default: "pending", null: false
      add :submitted_at, :utc_datetime
      add :verified_at, :utc_datetime
      add :rejected_at, :utc_datetime
      add :rejection_reason, :string
      
      # Admin notes
      add :admin_notes, :text
      
      add :store_id, references(:stores, on_delete: :delete_all), null: false

      timestamps()
    end

    # Indexes for performance and constraints
    create index(:store_kyc, [:status])
    create index(:store_kyc, [:business_type])
    create index(:store_kyc, [:tax_id])
    create unique_index(:store_kyc, [:store_id])
  end
end
