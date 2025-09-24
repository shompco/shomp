defmodule Shomp.Repo.Migrations.RecreateReviewsTable do
  use Ecto.Migration

  def change do
    # Drop dependent tables first
    drop_if_exists table(:review_responses)
    drop_if_exists table(:review_flags)
    
    # Drop existing reviews table (it has wrong schema) - skip if fresh database
    # drop table(:reviews)
    
    # Create new reviews table with correct schema
    create table(:reviews) do
      add :immutable_id, :string, null: false
      add :rating, :integer, null: false
      add :review_text, :text, null: false
      add :helpful_count, :integer, default: 0, null: false
      add :verified_purchase, :boolean, default: true, null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      
      timestamps(type: :utc_datetime)
    end

    # Create review_votes table
    create table(:review_votes) do
      add :helpful, :boolean, null: false
      add :review_id, references(:reviews, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      
      timestamps(type: :utc_datetime)
    end

    # Indexes
    create unique_index(:reviews, [:immutable_id])
    create unique_index(:reviews, [:user_id, :product_id], name: :user_can_only_review_once_per_product)
    create index(:reviews, [:product_id])
    create index(:reviews, [:user_id])
    create index(:reviews, [:rating])
    create index(:reviews, [:inserted_at])
    
    create unique_index(:review_votes, [:user_id, :review_id], name: :user_can_only_vote_once_per_review)
    create index(:review_votes, [:review_id])
    create index(:review_votes, [:user_id])
  end
end
