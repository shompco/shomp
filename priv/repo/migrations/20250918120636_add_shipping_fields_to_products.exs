defmodule Shomp.Repo.Migrations.AddShippingFieldsToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :weight, :decimal, precision: 8, scale: 2, default: 1.0
      add :length, :decimal, precision: 8, scale: 2, default: 6.0
      add :width, :decimal, precision: 8, scale: 2, default: 4.0
      add :height, :decimal, precision: 8, scale: 2, default: 2.0
      add :weight_unit, :string, default: "lb"
      add :distance_unit, :string, default: "in"
    end
  end
end
