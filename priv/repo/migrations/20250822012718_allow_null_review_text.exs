defmodule Shomp.Repo.Migrations.AllowNullReviewText do
  use Ecto.Migration

  def change do
    alter table(:reviews) do
      modify :review_text, :text, null: true
    end
  end
end
