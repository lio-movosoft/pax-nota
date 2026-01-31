defmodule Nota.Repo.Migrations.RemoveIsCoverFromNoteImages do
  use Ecto.Migration

  def change do
    alter table(:note_images) do
      remove :is_cover, :boolean, default: false
    end
  end
end
