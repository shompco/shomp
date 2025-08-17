defmodule Shomp.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments) do
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :stripe_payment_id, :string, null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, default: "pending", null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:payments, [:stripe_payment_id])
    create index(:payments, [:product_id])
    create index(:payments, [:user_id])
    create index(:payments, [:status])
  end
end
