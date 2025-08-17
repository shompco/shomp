defmodule Shomp.Repo.Migrations.AddStripeProductIdToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :stripe_product_id, :string
    end

    create index(:products, [:stripe_product_id])
  end
end
