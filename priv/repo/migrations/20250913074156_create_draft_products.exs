defmodule Shomp.Repo.Migrations.CreateDraftProducts do
  use Ecto.Migration

  def change do
    create table(:draft_products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :description, :text
      add :price, :decimal, precision: 10, scale: 2
      add :type, :string, null: false
      add :store_id, :string, null: false
      add :category_id, :integer
      add :custom_category_id, :integer
      add :quantity, :integer, default: 0

      # R2 file URLs
      add :image_original_url, :string
      add :image_thumb_url, :string
      add :image_medium_url, :string
      add :image_large_url, :string
      add :image_extra_large_url, :string
      add :image_ultra_url, :string
      add :additional_images_urls, {:array, :string}, default: []
      add :digital_file_url, :string
      add :digital_file_type, :string

      # Metadata
      add :status, :string, default: "draft" # draft, published, archived
      add :user_id, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:draft_products, [:user_id])
    create index(:draft_products, [:store_id])
    create index(:draft_products, [:status])
    create index(:draft_products, [:inserted_at])
  end
end
