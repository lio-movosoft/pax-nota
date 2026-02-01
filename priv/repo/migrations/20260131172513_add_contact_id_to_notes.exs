defmodule Nota.Repo.Migrations.AddContactIdToNotes do
  use Ecto.Migration

  def change do
    alter table(:notes) do
      add :contact_id, references(:contacts, on_delete: :nilify_all)
    end

    create index(:notes, [:contact_id])
  end
end
