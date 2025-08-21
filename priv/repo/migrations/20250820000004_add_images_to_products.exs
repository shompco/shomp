defmodule Shomp.Repo.Migrations.AddImagesToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      # Product images - store paths to different size variants
      add :image_original, :string
      add :image_thumb, :string
      add :image_medium, :string
      add :image_large, :string
      add :image_extra_large, :string
      add :image_ultra, :string
      
      # Multiple images support (JSON array of image paths)
      add :additional_images, {:array, :string}, default: []
      
      # Image metadata
      add :primary_image_index, :integer, default: 0
    end
    
    # Create indexes for image fields
    create index(:products, [:image_original])
    create index(:products, [:image_thumb])
  end
end
