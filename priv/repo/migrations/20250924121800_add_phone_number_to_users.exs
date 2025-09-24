defmodule Shomp.Repo.Migrations.AddPhoneNumberToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :phone_number, :string
    end

    create index(:users, [:phone_number])
  end
end