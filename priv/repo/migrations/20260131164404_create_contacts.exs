defmodule Nota.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts) do
      add :first_name, :citext, null: false
      add :last_name, :citext
      add :email, :string
      add :phone, :string
      add :linkedin_url, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:user_id])
    create index(:contacts, [:first_name])
    create index(:contacts, [:last_name])
  end
end
