defmodule Nota.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
    create table(:notes) do
      add :title, :citext, null: false
      add :body, :citext
      add :user_id, references(:users, on_delete: :delete_all), null: false

      # tsvector column for full-text search
      add :search_title_body, :tsvector

      timestamps(type: :utc_datetime)
    end

    create index(:notes, [:user_id])

    # GIN index for fast full-text search
    create index(:notes, [:search_title_body], using: :gin)

    # Trigger function to update tsvector column on insert/update
    execute """
            CREATE OR REPLACE FUNCTION notes_search_trigger() RETURNS trigger AS $$
            BEGIN
              NEW.search_title_body :=
                setweight(
                  to_tsvector('simple', COALESCE(NEW.title, '')),
                  'A'
                ) ||
                setweight(
                  to_tsvector('english', COALESCE(NEW.body, '')),
                  'B'
                );
              RETURN NEW;
            END
            $$ LANGUAGE plpgsql;
            """,
            "DROP FUNCTION IF EXISTS notes_search_trigger();"

    execute """
            CREATE TRIGGER notes_search_update
            BEFORE INSERT OR UPDATE ON notes
            FOR EACH ROW EXECUTE FUNCTION notes_search_trigger();
            """,
            "DROP TRIGGER IF EXISTS notes_search_update ON notes;"
  end
end
