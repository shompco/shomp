defmodule Shomp.Repo.Migrations.UpdateKycDocumentPaths do
  use Ecto.Migration

  def up do
    # Update existing KYC records to use just the filename instead of full path
    execute """
    UPDATE store_kyc 
    SET id_document_path = SUBSTRING(id_document_path FROM '[^/]+$')
    WHERE id_document_path IS NOT NULL 
    AND id_document_path LIKE '/uploads/kyc/%'
    """
  end

  def down do
    # Revert back to full paths (this is not perfect but provides a rollback)
    execute """
    UPDATE store_kyc 
    SET id_document_path = '/uploads/kyc/' || id_document_path
    WHERE id_document_path IS NOT NULL 
    AND id_document_path NOT LIKE '/uploads/kyc/%'
    """
  end
end