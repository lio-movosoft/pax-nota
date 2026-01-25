defmodule Nota.Repo.Migrations.CreateNoteImages do
  use Ecto.Migration

  def change do
    create table(:note_images) do
      add :image_key, :string, null: false
      add :is_cover, :boolean, default: false, null: false
      add :note_id, references(:notes, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:note_images, [:note_id])
    create unique_index(:note_images, [:note_id, :is_cover], where: "is_cover = true", name: :note_images_one_cover_per_note)
  end
end
