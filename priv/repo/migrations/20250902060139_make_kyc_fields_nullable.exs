defmodule Shomp.Repo.Migrations.MakeKycFieldsNullable do
  use Ecto.Migration

  def change do
    alter table(:store_kyc) do
      modify :legal_name, :string, null: true
      modify :business_type, :string, null: true
      modify :tax_id, :string, null: true
      modify :address_line_1, :string, null: true
      modify :address_line_2, :string, null: true
      modify :city, :string, null: true
      modify :state, :string, null: true
      modify :zip_code, :string, null: true
      modify :phone, :string, null: true
      modify :email, :string, null: true
      modify :id_document_path, :string, null: true
      modify :business_license_path, :string, null: true
      modify :tax_document_path, :string, null: true
    end
  end
end
