defmodule Nota.Repo.Migrations.AddProcessingStatusToNoteImages do
  use Ecto.Migration

  def change do
    alter table(:note_images) do
      add :processing_status, :string, default: "completed", null: false
    end
  end
end
