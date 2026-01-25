defmodule Nota.Notes.NoteImage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Nota.Notes.Note

  schema "note_images" do
    field :image_key, :string
    field :is_cover, :boolean, default: false

    belongs_to :note, Note

    timestamps(type: :utc_datetime)
  end

  def changeset(note_image, attrs) do
    note_image
    |> cast(attrs, [:image_key, :is_cover, :note_id])
    |> validate_required([:image_key, :note_id])
  end
end
