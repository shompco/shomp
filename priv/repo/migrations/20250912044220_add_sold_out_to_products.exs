defmodule Shomp.Repo.Migrations.AddSoldOutToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :sold_out, :boolean, default: false, null: false
    end
  end
end
