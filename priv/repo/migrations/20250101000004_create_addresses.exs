defmodule Shomp.Repo.Migrations.CreateAddresses do
  use Ecto.Migration

  def change do
    create table(:addresses) do
      add :immutable_id, :string, null: false
      add :type, :string, null: false # billing, shipping
      add :name, :string, null: false # Full name for the address
      add :street, :string, null: false
      add :city, :string, null: false
      add :state, :string, null: false
      add :zip_code, :string, null: false
      add :country, :string, default: "US", null: false
      add :is_default, :boolean, default: false
      add :label, :string # "Home", "Work", etc.
      
      add :user_id, references(:users, on_delete: :delete_all), null: false
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:addresses, [:immutable_id])
    create index(:addresses, [:user_id])
    create index(:addresses, [:type])
    create index(:addresses, [:is_default])
  end
end