defmodule Nota.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :label, :citext, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Each user can only have one tag with a given label
    create unique_index(:tags, [:user_id, :label])
    create index(:tags, [:user_id])

    create table(:notes_tags, primary_key: false) do
      add :note_id, references(:notes, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:notes_tags, [:note_id, :tag_id])
    create index(:notes_tags, [:tag_id])
  end
end
